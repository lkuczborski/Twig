/// How worktrees are arranged after the pinned section.
public enum WorktreeSortOrder: String, CaseIterable, Codable, Sendable {
    /// Keep the activity order supplied by the caller across all repositories.
    case activity
    /// Sort repositories by name, keeping activity order within each repository.
    case project
}
