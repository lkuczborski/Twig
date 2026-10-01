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

    public init() {}
    public static var full: Self {
        var value = Self()
        value.worktrees = true; value.allProjects = true; value.applications = true
        return value
    }
    public var isEmpty: Bool { !worktrees && !applications && !reconfigureWatcher }
    public mutating func merge(_ other: Self) {
        worktrees = worktrees || other.worktrees
        allProjects = allProjects || other.allProjects
        projectIDs.formUnion(other.projectIDs)
        applications = applications || other.applications
        reconfigureWatcher = reconfigureWatcher || other.reconfigureWatcher
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

    public init(worktreesRoot: URL, worktrees: [WatchedWorktree], applicationDirectories: [URL]) {
        self.worktreesRoot = worktreesRoot
        self.worktrees = worktrees
        self.applicationDirectories = applicationDirectories
    }

    public var watchRoots: [URL] {
        let desired = [worktreesRoot] + applicationDirectories + worktrees.flatMap {
            [$0.gitDirectory, $0.commonGitDirectory].compactMap { $0 }
        }
        return FileEventWatcher.minimalRoots(desired.map { FileEventWatcher.existingWatchRoot(for: $0) })
    }

    public func classify(_ events: [FilesystemEvent]) -> RefreshRequest {
        var result = RefreshRequest()
        let root = canonicalPath(worktreesRoot.path)
        let applicationRoots = applicationDirectories.map { canonicalPath($0.path) }
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
            if isWithin(path, root: root) {
                let matches = worktrees.filter { isWithin(path, root: canonicalPath($0.folder.path)) }
                if matches.isEmpty {
                    result.worktrees = true
                    result.allProjects = true
                } else {
                    for tree in matches {
                        let folder = canonicalPath(tree.folder.path)
                        let components = String(path.dropFirst(folder.count)).split(separator: "/").map(String.init)
                        guard !components.contains(where: Self.ignoredDirectories.contains) else { continue }
                        result.worktrees = true
                        result.projectIDs.insert(tree.id)
                    }
                }
            } else if isWithin(root, root: path) {
                // Creation/removal/rename of the configured root can be coalesced to its ancestor.
                result.worktrees = true
                result.allProjects = true
            }
            for tree in worktrees {
                if let git = tree.gitDirectory, isWithin(path, root: canonicalPath(git.path)) {
                    result.worktrees = true
                }
                if let common = tree.commonGitDirectory {
                    let common = canonicalPath(common.path)
                    if path == common || isWithin(path, root: common + "/refs") {
                        result.worktrees = true
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
