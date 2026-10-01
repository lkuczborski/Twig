import Foundation

/// An existing local checkout managed inside Codex's worktrees directory.
public struct Worktree: Identifiable, Hashable, Sendable {
    /// The canonical checkout path. Stable across branch changes.
    public let id: String
    public let folder: URL
    public let repositoryName: String
    /// The current Git branch, or nil for a detached HEAD.
    public let branch: String?
    public let headRevision: String?
    /// The latest observed filesystem or Git activity, not a Codex chat timestamp.
    public let lastActivity: Date
    /// Linked worktree Git metadata lives outside the checkout and must also be watched.
    public let gitDirectory: URL?
    public let commonGitDirectory: URL?

    public init(
        id: String,
        folder: URL,
        repositoryName: String,
        branch: String?,
        headRevision: String?,
        lastActivity: Date,
        gitDirectory: URL? = nil,
        commonGitDirectory: URL? = nil
    ) {
        self.id = id
        self.folder = folder
        self.repositoryName = repositoryName
        self.branch = branch
        self.headRevision = headRevision
        self.lastActivity = lastActivity
        self.gitDirectory = gitDirectory
        self.commonGitDirectory = commonGitDirectory
    }
}

public struct WorktreeDiscoveryResult: Sendable {
    public let worktrees: [Worktree]
    public let warnings: [String]

    public init(worktrees: [Worktree], warnings: [String]) {
        self.worktrees = worktrees
        self.warnings = warnings
    }
}
