import Foundation

/// A presentation group that preserves the supplied order within each section.
public struct WorktreeSection: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String?
    public let isRepositoryGroup: Bool
    public let worktrees: [Worktree]
}

public enum WorktreeOrganization {
    /// Pins occur once at the top in supplied activity order. Project sorting uses
    /// shared Git metadata, so unrelated repositories with the same name stay separate.
    public static func sections(
        _ worktrees: [Worktree], pinnedIDs: Set<String>, sortOrder: WorktreeSortOrder
    ) -> [WorktreeSection] {
        var seen: Set<String> = []
        let unique = worktrees.filter { seen.insert($0.id).inserted }
        let pinned = unique.filter { pinnedIDs.contains($0.id) }
        let remaining = unique.filter { !pinnedIDs.contains($0.id) }
        var sections: [WorktreeSection] = []
        if !pinned.isEmpty {
            sections.append(WorktreeSection(id: "pinned", title: "Pinned", isRepositoryGroup: false, worktrees: pinned))
        }
        guard sortOrder == .project else {
            if !remaining.isEmpty {
                sections.append(WorktreeSection(id: "recent", title: pinned.isEmpty ? nil : "Recent", isRepositoryGroup: false, worktrees: remaining))
            }
            return sections
        }

        // Dictionary grouping keeps the supplied order inside each repository.
        // Every repository gets a heading, including a single remaining checkout.
        let repositorySections = Dictionary(grouping: remaining, by: RepositoryIdentity.key(for:))
            .map { key, group in
                WorktreeSection(id: "repository:\(key)", title: group[0].repositoryName,
                                isRepositoryGroup: true, worktrees: group)
            }
            .sorted {
                let comparison = ($0.title ?? "").localizedStandardCompare($1.title ?? "")
                // Keep same-name repositories stable when activity order changes.
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }
        sections.append(contentsOf: repositorySections)
        return sections
    }
}
