import Foundation

public struct WatchedWorktree: Sendable {
    public let id: String
    public let folder: URL
    public let gitDirectory: URL?
    public let commonGitDirectory: URL?

    public init(id: String, folder: URL, gitDirectory: URL? = nil, commonGitDirectory: URL? = nil) {
        self.id = id
        self.folder = folder
        self.gitDirectory = gitDirectory
        self.commonGitDirectory = commonGitDirectory
    }
}

public struct RefreshRequest: Sendable, Equatable {
    public var worktrees = false
    public var allProjects = false
    public var projectIDs: Set<String> = []
    public var applications = false
    public var reconfigureWatcher = false
    public var allGitStatuses = false
    public var gitStatusIDs: Set<String> = []

    public init() {}
    public static var full: Self {
        var value = Self()
        value.worktrees = true; value.allProjects = true; value.applications = true
        value.allGitStatuses = true
        return value
    }
    public var isEmpty: Bool { !worktrees && !applications && !reconfigureWatcher && !allGitStatuses && gitStatusIDs.isEmpty }
    public mutating func merge(_ other: Self) {
        worktrees = worktrees || other.worktrees
        allProjects = allProjects || other.allProjects
        projectIDs.formUnion(other.projectIDs)
        applications = applications || other.applications
        reconfigureWatcher = reconfigureWatcher || other.reconfigureWatcher
        allGitStatuses = allGitStatuses || other.allGitStatuses
        gitStatusIDs.formUnion(other.gitStatusIDs)
    }
}

/// No timer or scan is scheduled when hidden. Changes arriving during a scan remain pending.
public struct RefreshState: Sendable {
    public var isVisible = false
    public private(set) var pending = RefreshRequest.full
    public init() {}
    public mutating func invalidate(_ request: RefreshRequest) { pending.merge(request) }
    public mutating func takePending(allowWhileHidden: Bool = false) -> RefreshRequest? {
        guard (isVisible || allowWhileHidden), !pending.isEmpty else { return nil }
        let request = pending
        pending = RefreshRequest()
        return request
    }
}

/// Routes directory-level events without reading their contents or rescanning unrelated checkouts.
public struct ChangeRouting: Sendable {
    public let worktreesRoot: URL
    public let worktrees: [WatchedWorktree]
    public let applicationDirectories: [URL]
    public let repositoryRoots: [URL]
    public let repositoryGitDirectories: [URL]

    public init(worktreesRoot: URL, worktrees: [WatchedWorktree], applicationDirectories: [URL],
                repositoryRoots: [URL] = [], repositoryGitDirectories: [URL] = []) {
        self.worktreesRoot = worktreesRoot
        self.worktrees = worktrees
        self.applicationDirectories = applicationDirectories
        self.repositoryRoots = repositoryRoots
        self.repositoryGitDirectories = repositoryGitDirectories
    }

    public var watchRoots: [URL] {
        let desired = [worktreesRoot] + applicationDirectories + repositoryRoots + repositoryGitDirectories + worktrees.map(\.folder) + worktrees.flatMap {
            [$0.gitDirectory, $0.commonGitDirectory].compactMap { $0 }
        }
        return FileEventWatcher.minimalRoots(desired.map { FileEventWatcher.existingWatchRoot(for: $0) })
    }

    public func classify(_ events: [FilesystemEvent]) -> RefreshRequest {
        var result = RefreshRequest()
        let root = canonicalPath(worktreesRoot.path)
        let applicationRoots = applicationDirectories.map { canonicalPath($0.path) }
        let explicitRoots = repositoryRoots.map { canonicalPath($0.path) }
        let metadataRoots = Set((repositoryGitDirectories + worktrees.flatMap {
            [$0.gitDirectory, $0.commonGitDirectory].compactMap { $0 }
        }).map { canonicalPath($0.path) })
        for event in events {
            let path = canonicalPath(event.path)
            // Lost events and moved roots are advisory: discard inference caches and rebuild subscriptions.
            if event.requiresFullRescan {
                result.merge(.full)
                result.reconfigureWatcher = true
                continue
            }
            if applicationRoots.contains(where: { isWithin(path, root: $0) || isWithin($0, root: path) }) {
                // Parent notifications also catch a previously absent ~/Applications directory.
                result.applications = true
            }
            let matches = worktrees.filter { isWithin(path, root: canonicalPath($0.folder.path)) }
            for tree in matches {
                let folder = canonicalPath(tree.folder.path)
                let components = String(path.dropFirst(folder.count)).split(separator: "/").map(String.init)
                // A normally ignored build/dependency directory can contain tracked files.
                // Let Git apply the checkout's own ignore rules without rerunning project detection.
                if components.first != ".git" { result.gitStatusIDs.insert(tree.id) }
                guard !components.contains(where: Self.ignoredDirectories.contains) else { continue }
                result.worktrees = true
                result.projectIDs.insert(tree.id)
            }
            for tree in worktrees where isWithin(canonicalPath(tree.folder.path), root: path) && path != canonicalPath(tree.folder.path) {
                result.worktrees = true
                result.allProjects = true
                result.gitStatusIDs.insert(tree.id)
                result.reconfigureWatcher = true
            }
            if (isWithin(path, root: root) && matches.isEmpty) || isWithin(root, root: path) {
                // Creation/removal/rename of the configured root can be coalesced to its ancestor.
                result.worktrees = true
                result.allProjects = true
            }
            for explicitRoot in explicitRoots {
                if isWithin(explicitRoot, root: path) {
                    result.worktrees = true
                    result.reconfigureWatcher = true
                } else if isWithin(path, root: explicitRoot), matches.isEmpty,
                          !metadataRoots.contains(where: { isWithin(path, root: $0) }) {
                    let components = String(path.dropFirst(explicitRoot.count)).split(separator: "/").map(String.init)
                    let newGitMetadata = components.first == ".git" && !["objects", "hooks"].contains(components.dropFirst().first ?? "")
                    guard !components.contains(where: Self.ignoredDirectories.contains) || newGitMetadata else { continue }
                    result.worktrees = true
                    result.reconfigureWatcher = true
                }
            }
            for metadata in metadataRoots where isWithin(path, root: metadata) {
                let components = String(path.dropFirst(metadata.count)).split(separator: "/").map(String.init)
                if components.isEmpty || ["HEAD", "index", "packed-refs", "refs", "logs", "commondir", "gitdir", "config", "info"].contains(components.first ?? "") {
                    result.worktrees = true
                    for tree in worktrees where [tree.gitDirectory, tree.commonGitDirectory].compactMap({ $0 }).contains(where: { canonicalPath($0.path) == metadata }) {
                        result.gitStatusIDs.insert(tree.id)
                    }
                } else if components.first == "worktrees" {
                    result.worktrees = true
                    let affected = worktrees.filter { tree in
                        guard let gitDirectory = tree.gitDirectory else { return false }
                        let directory = canonicalPath(gitDirectory.path)
                        return isWithin(path, root: directory) || isWithin(directory, root: path)
                    }
                    result.gitStatusIDs.formUnion(affected.map(\.id))
                    // Index/log events for a known registration do not invalidate every
                    // repository. An unknown registration may introduce a new external root.
                    if affected.isEmpty || components.count == 1 {
                        result.reconfigureWatcher = true
                    }
                }
            }
        }
        return result
    }

    private static let ignoredDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "node_modules", "vendor", "Pods", "Carthage", "DerivedData",
        "build", "dist", "target", ".gradle", ".next", ".nuxt", ".cache", ".turbo", ".venv",
        "venv", "__pycache__", ".pytest_cache", "coverage", ".yarn", ".pnpm-store", ".dart_tool"
    ]
}
