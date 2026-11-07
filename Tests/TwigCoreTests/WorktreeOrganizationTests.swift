import Foundation
import Testing
@testable import TwigCore

struct WorktreeOrganizationTests {
    @Test
    func pinsAppearOnceBeforeRepositoryGroups() {
        let a = worktree("a", repository: "Atlas", common: "/projects/Atlas/.git")
        let b = worktree("b", repository: "Atlas", common: "/projects/Atlas/.git")
        let c = worktree("c", repository: "Atlas", common: "/projects/Atlas/.git")
        let sections = WorktreeOrganization.sections([a, b, c, b], pinnedIDs: [b.id], groupByRepository: true)
        #expect(sections.map(\.id).first == "pinned")
        #expect(sections.first?.worktrees.map(\.id) == [b.id])
        #expect(sections.last?.title == "Atlas")
        #expect(sections.last?.worktrees.map(\.id) == [a.id, c.id])
        #expect(sections.flatMap(\.worktrees).count == 3)
    }

    @Test
    func equalNamesFromDifferentRepositoriesStaySeparate() {
        let a = worktree("a", repository: "App", common: "/first/App/.git")
        let b = worktree("b", repository: "App", common: "/second/App/.git")
        let c = worktree("c", repository: "App", common: "/first/App/.git")
        let sections = WorktreeOrganization.sections([a, b, c], pinnedIDs: [], groupByRepository: true)
        #expect(sections.count == 2)
        #expect(sections[0].worktrees.map(\.id) == [a.id, c.id])
        #expect(sections[1].worktrees.map(\.id) == [b.id])
        #expect(sections[0].isRepositoryGroup)
        #expect(!sections[1].isRepositoryGroup)
    }

    @Test
    func groupingPreservesFirstAppearanceAndWithinGroupOrder() {
        let a = worktree("a", repository: "First", common: "/first/.git")
        let b = worktree("b", repository: "Second", common: "/second/.git")
        let c = worktree("c", repository: "First", common: "/first/.git")
        let d = worktree("d", repository: "Second", common: "/second/.git")
        let sections = WorktreeOrganization.sections([b, a, c, d], pinnedIDs: [], groupByRepository: true)
        #expect(sections.map(\.title) == ["Second", "First"])
        #expect(sections.flatMap(\.worktrees).map(\.id) == [b.id, d.id, a.id, c.id])
    }

    @Test
    func ungroupedSearchCanPreserveRankWithoutPins() {
        let a = worktree("a", repository: "Atlas", common: "/Atlas/.git")
        let b = worktree("b", repository: "Atlas", common: "/Atlas/.git")
        let sections = WorktreeOrganization.sections([b, a], pinnedIDs: [], groupByRepository: false)
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].worktrees.map(\.id) == [b.id, a.id])
    }

    @Test
    func missingRepositoryMetadataDoesNotMergeUnrelatedWorktrees() {
        let a = worktree("a", repository: "App", common: nil)
        let b = worktree("b", repository: "App", common: nil)
        #expect(WorktreeOrganization.sections([a, b], pinnedIDs: [], groupByRepository: true).count == 2)
        #expect(WorktreeOrganization.sections([], pinnedIDs: [a.id], groupByRepository: true).isEmpty)
    }

    @Test
    func canonicalCommonDirectoryAliasesGroupTogether() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigGrouping-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let common = root.appendingPathComponent("repository.git")
        let alias = root.appendingPathComponent("alias.git")
        try FileManager.default.createDirectory(at: common, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: common)
        let a = worktree("a", repository: "App", common: common.path)
        let b = worktree("b", repository: "App", common: alias.path)
        #expect(WorktreeOrganization.sections([a, b], pinnedIDs: [], groupByRepository: true).count == 1)
    }

    private func worktree(_ name: String, repository: String, common: String?) -> Worktree {
        let folder = URL(fileURLWithPath: "/tmp/worktrees/\(name)")
        return Worktree(id: WorktreePath.key(for: folder), folder: folder, repositoryName: repository,
                        branch: "feature/\(name)", headRevision: nil, lastActivity: .distantPast,
                        commonGitDirectory: common.map { URL(fileURLWithPath: $0) })
    }
}
