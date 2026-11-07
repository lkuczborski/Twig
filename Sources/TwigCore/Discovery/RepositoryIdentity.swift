import Foundation

/// A repository preference belongs to its shared Git metadata, not its display name.
public enum RepositoryIdentity {
    public static func key(for worktree: Worktree) -> String {
        WorktreePath.key(for: worktree.commonGitDirectory ?? worktree.gitDirectory ?? worktree.folder)
    }
}
