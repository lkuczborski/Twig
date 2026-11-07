import Foundation

public struct WorktreeCatalogResult: Sendable {
    public let worktrees: [Worktree]
    public let warnings: [String]
    public let repositoryStatuses: [RepositoryRootStatus]
}

/// Combines independent discovery sources using canonical checkout identities.
public struct WorktreeCatalog: Sendable {
    public init() {}

    public func discover(codexHome: URL, repositoryRoots: [URL] = []) -> WorktreeCatalogResult {
        let automatic = WorktreeDiscoverer().discover(in: codexHome)
        var found = Dictionary(uniqueKeysWithValues: automatic.worktrees.map { ($0.id, $0) })
        var warnings = automatic.warnings
        var statuses: [RepositoryRootStatus] = []
        var seenRoots: Set<String> = []
        for root in repositoryRoots {
            if Task.isCancelled { break }
            guard seenRoots.insert(WorktreePath.key(for: root)).inserted else { continue }
            let result = RepositoryDiscoverer().discover(at: root)
            for worktree in result.worktrees { found[worktree.id] = worktree }
            warnings += result.warnings
            statuses.append(result.status)
        }
        return WorktreeCatalogResult(worktrees: found.values.sorted {
            $0.lastActivity == $1.lastActivity ? $0.id < $1.id : $0.lastActivity > $1.lastActivity
        }, warnings: warnings, repositoryStatuses: statuses)
    }
}
