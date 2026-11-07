import Foundation
import Testing
@testable import TwigCore

struct WorktreeOrganizationTests {
    @Test(arguments: WorktreeSortOrder.allCases)
    func pinsAppearOnceFirstInSuppliedActivityOrder(sortOrder: WorktreeSortOrder) {
        let a = worktree("a", repository: "Atlas", common: "/projects/Atlas/.git")
        let b = worktree("b", repository: "Atlas", common: "/projects/Atlas/.git")
        let c = worktree("c", repository: "Website", common: "/projects/Website/.git")
        let d = worktree("d", repository: "Atlas", common: "/projects/Atlas/.git")
        let sections = WorktreeOrganization.sections([c, a, b, d, b], pinnedIDs: [b.id, c.id], sortOrder: sortOrder)
        #expect(sections.first?.id == "pinned")
        #expect(sections.first?.title == "Pinned")
        #expect(sections.first?.isRepositoryGroup == false)
        #expect(sections.first?.worktrees.map(\.id) == [c.id, b.id])
        #expect(sections.last?.worktrees.map(\.id) == [a.id, d.id])
        #expect(sections.flatMap(\.worktrees).map(\.id) == [c.id, b.id, a.id, d.id])
    }

    @Test
    func activityKeepsRepositoriesInterleavedAfterPins() {
        let a = worktree("a", repository: "Atlas", common: "/Atlas/.git")
        let b = worktree("b", repository: "Website", common: "/Website/.git")
        let c = worktree("c", repository: "Atlas", common: "/Atlas/.git")
        let pinned = worktree("pinned", repository: "Grove", common: "/Grove/.git")
        let sections = WorktreeOrganization.sections([a, b, pinned, c], pinnedIDs: [pinned.id], sortOrder: .activity)
        #expect(sections.map(\.title) == ["Pinned", "Recent"])
        #expect(sections[1].worktrees.map(\.id) == [a.id, b.id, c.id])
        #expect(sections.allSatisfy { !$0.isRepositoryGroup })
    }

    @Test
    func projectSortsEveryRepositoryAndPreservesActivityWithinEach() {
        let a = worktree("a", repository: "Atlas", common: "/Atlas/.git")
        let b = worktree("b", repository: "Atlas", common: "/Atlas/.git")
        let grove = worktree("grove", repository: "Grove", common: "/Grove/.git")
        let website = worktree("website", repository: "Website", common: "/Website/.git")
        let sections = WorktreeOrganization.sections([website, b, grove, a], pinnedIDs: [], sortOrder: .project)
        #expect(sections.map(\.title) == ["Atlas", "Grove", "Website"])
        #expect(sections.flatMap(\.worktrees).map(\.id) == [b.id, a.id, grove.id, website.id])
        #expect(sections.allSatisfy(\.isRepositoryGroup))
    }

    @Test
    func projectNamesUseNaturalAlphabeticalOrder() {
        let names = ["Zebra", "App10", "beta", "App2", "alpha"]
        let worktrees = names.map { worktree($0, repository: $0, common: "/projects/\($0)/.git") }
        let sections = WorktreeOrganization.sections(worktrees, pinnedIDs: [], sortOrder: .project)
        #expect(sections.map(\.title) == ["alpha", "App2", "App10", "beta", "Zebra"])
    }

    @Test
    func equalNamesFromDifferentRepositoriesHaveStableSeparateSections() {
        let a = worktree("a", repository: "App", common: "/first/App/.git")
        let b = worktree("b", repository: "App", common: "/second/App/.git")
        let c = worktree("c", repository: "App", common: "/first/App/.git")
        let sections = WorktreeOrganization.sections([b, a, c], pinnedIDs: [], sortOrder: .project)
        #expect(sections.count == 2)
        #expect(sections.map(\.title) == ["App", "App"])
        #expect(sections[0].worktrees.map(\.id) == [a.id, c.id])
        #expect(sections[1].worktrees.map(\.id) == [b.id])
        #expect(sections[0].id != sections[1].id)
        #expect(sections.allSatisfy(\.isRepositoryGroup))

        let changedActivity = WorktreeOrganization.sections([c, b, a], pinnedIDs: [], sortOrder: .project)
        #expect(changedActivity.map(\.id) == sections.map(\.id))
        #expect(changedActivity[0].worktrees.map(\.id) == [c.id, a.id])
    }

    @Test
    func activityWithoutPinsPreservesFlatSearchRank() {
        let a = worktree("a", repository: "Atlas", common: "/Atlas/.git")
        let b = worktree("b", repository: "Website", common: "/Website/.git")
        let c = worktree("c", repository: "Atlas", common: "/Atlas/.git")
        let sections = WorktreeOrganization.sections([c, b, a], pinnedIDs: [], sortOrder: .activity)
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(!sections[0].isRepositoryGroup)
        #expect(sections[0].worktrees.map(\.id) == [c.id, b.id, a.id])
    }

    @Test
    func missingRepositoryMetadataDoesNotMergeUnrelatedWorktrees() {
        let a = worktree("a", repository: "App", common: nil)
        let b = worktree("b", repository: "App", common: nil)
        let sections = WorktreeOrganization.sections([b, a], pinnedIDs: [], sortOrder: .project)
        #expect(sections.count == 2)
        #expect(sections.map(\.title) == ["App", "App"])
        #expect(sections[0].worktrees.map(\.id) == [a.id])
        #expect(sections[1].worktrees.map(\.id) == [b.id])
        #expect(sections.allSatisfy(\.isRepositoryGroup))
    }

    @Test
    func projectSingletonsIncludingPinnedSiblingsHaveVisibleBoundaries() {
        let pinned = worktree("pinned", repository: "Atlas", common: "/Atlas/.git")
        let sibling = worktree("sibling", repository: "Atlas", common: "/Atlas/.git")
        let other = worktree("other", repository: "Twig", common: "/Twig/.git")
        let sections = WorktreeOrganization.sections([other, pinned, sibling], pinnedIDs: [pinned.id], sortOrder: .project)
        #expect(sections.map(\.title) == ["Pinned", "Atlas", "Twig"])
        #expect(sections[1].worktrees.map(\.id) == [sibling.id])
        #expect(sections[2].worktrees.map(\.id) == [other.id])
        #expect(sections.dropFirst().allSatisfy { $0.isRepositoryGroup })
    }

    @Test(arguments: WorktreeSortOrder.allCases)
    func allPinnedWorktreesDoNotLeaveEmptySections(sortOrder: WorktreeSortOrder) {
        let a = worktree("a", repository: "Atlas", common: "/Atlas/.git")
        let b = worktree("b", repository: "Twig", common: "/Twig/.git")
        let sections = WorktreeOrganization.sections([b, a], pinnedIDs: [a.id, b.id, "missing"], sortOrder: sortOrder)
        #expect(sections.count == 1)
        #expect(sections[0].id == "pinned")
        #expect(sections[0].worktrees.map(\.id) == [b.id, a.id])
    }

    @Test(arguments: WorktreeSortOrder.allCases)
    func missingPinnedWorktreesDoNotCreateSections(sortOrder: WorktreeSortOrder) {
        #expect(WorktreeOrganization.sections([], pinnedIDs: ["missing"], sortOrder: sortOrder).isEmpty)
        let a = worktree("a", repository: "Atlas", common: "/Atlas/.git")
        let sections = WorktreeOrganization.sections([a], pinnedIDs: ["missing"], sortOrder: sortOrder)
        #expect(sections.count == 1)
        #expect(sections[0].id != "pinned")
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
        let sections = WorktreeOrganization.sections([b, a], pinnedIDs: [], sortOrder: .project)
        #expect(sections.count == 1)
        #expect(sections[0].worktrees.map(\.id) == [b.id, a.id])
    }

    private func worktree(_ name: String, repository: String, common: String?) -> Worktree {
        let folder = URL(fileURLWithPath: "/tmp/worktrees/\(name)")
        return Worktree(id: WorktreePath.key(for: folder), folder: folder, repositoryName: repository,
                        branch: "feature/\(name)", headRevision: nil, lastActivity: .distantPast,
                        commonGitDirectory: common.map { URL(fileURLWithPath: $0) })
    }
}
