import Foundation

/// A presentation group that preserves the supplied order within each section.
public struct WorktreeSection: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String?
    public let isRepositoryGroup: Bool
    public let worktrees: [Worktree]
}

public enum WorktreeOrganization {
    /// Pins occur once at the top. Repositories are identified by their shared Git
    /// metadata, so unrelated projects with the same folder name never coalesce.
    public static func sections(
        _ worktrees: [Worktree], pinnedIDs: Set<String>, groupByRepository: Bool
    ) -> [WorktreeSection] {
        var seen: Set<String> = []
        let unique = worktrees.filter { seen.insert($0.id).inserted }
        let pinned = unique.filter { pinnedIDs.contains($0.id) }
        let remaining = unique.filter { !pinnedIDs.contains($0.id) }
        var sections: [WorktreeSection] = []
        if !pinned.isEmpty {
            sections.append(WorktreeSection(id: "pinned", title: "Pinned", isRepositoryGroup: false, worktrees: pinned))
        }
        guard groupByRepository else {
            if !remaining.isEmpty {
                sections.append(WorktreeSection(id: "recent", title: pinned.isEmpty ? nil : "Recent", isRepositoryGroup: false, worktrees: remaining))
            }
            return sections
        }

        let groups = Dictionary(grouping: remaining, by: repositoryKey)
        var emitted: Set<String> = []
        for worktree in remaining {
            let key = repositoryKey(worktree)
            guard emitted.insert(key).inserted, let group = groups[key], group.count > 1 else { continue }
            sections.append(WorktreeSection(
                id: "repository:\(key)", title: worktree.repositoryName,
                isRepositoryGroup: true, worktrees: group
            ))
        }
        // A row with no heading after Pinned or a repository heading appears to
        // belong to that section. Give unrelated singletons one clear boundary.
        let singletons = remaining.filter { groups[repositoryKey($0)]?.count == 1 }
        if !singletons.isEmpty {
            let hasRepositoryGroups = sections.contains(where: \.isRepositoryGroup)
            sections.append(WorktreeSection(
                id: hasRepositoryGroups ? "other" : "recent",
                title: hasRepositoryGroups ? "Other worktrees" : (pinned.isEmpty ? nil : "Recent"),
                isRepositoryGroup: false, worktrees: singletons
            ))
        }
        return sections
    }

    private static func repositoryKey(_ worktree: Worktree) -> String {
        RepositoryIdentity.key(for: worktree)
    }
}
