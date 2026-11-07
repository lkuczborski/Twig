import Foundation
import Testing
@testable import TwigSync

struct ChangeRoutingTests {
    private let root = URL(fileURLWithPath: "/tmp/twig-routing/codex/worktrees")
    private var tree: WatchedWorktree {
        WatchedWorktree(id: "one", folder: root.appendingPathComponent("abc/App"),
                        gitDirectory: URL(fileURLWithPath: "/tmp/twig-routing/repo/.git/worktrees/App"),
                        commonGitDirectory: URL(fileURLWithPath: "/tmp/twig-routing/repo/.git"))
    }
    private var router: ChangeRouting {
        ChangeRouting(worktreesRoot: root, worktrees: [tree],
                      applicationDirectories: [URL(fileURLWithPath: "/Applications")])
    }

    @Test func checkoutChangesInvalidateOnlyThatProjectsDetection() {
        let request = router.classify([FilesystemEvent(path: tree.folder.appendingPathComponent("Sources").path)])
        #expect(request.worktrees)
        #expect(request.projectIDs == ["one"])
        #expect(!request.allProjects)
        #expect(!request.applications)
    }

    @Test func branchSwitchesOutsideTheCheckoutRefreshMetadataOnly() {
        let request = router.classify([FilesystemEvent(path: tree.gitDirectory!.path)])
        #expect(request.worktrees)
        #expect(request.projectIDs.isEmpty)
        #expect(!request.allProjects)
    }

    @Test func packedRefsAndLooseRefsAreObservedButGitObjectsAreIgnored() {
        #expect(router.classify([FilesystemEvent(path: tree.commonGitDirectory!.path)]).worktrees)
        #expect(router.classify([FilesystemEvent(path: tree.commonGitDirectory!.appendingPathComponent("refs/heads").path)]).worktrees)
        #expect(router.classify([FilesystemEvent(path: tree.commonGitDirectory!.appendingPathComponent("objects/ab").path)]).isEmpty)
    }

    @Test func dependencyAndBuildEventsOnlyRefreshGitStatusWithoutProjectDetection() {
        for relative in ["node_modules/package", ".build/debug", "build/tmp", "dist/assets", "Pods/Foo"] {
            let request = router.classify([FilesystemEvent(path: tree.folder.appendingPathComponent(relative).path)])
            #expect(!request.worktrees)
            #expect(request.projectIDs.isEmpty)
            #expect(request.gitStatusIDs == ["one"])
        }
        #expect(router.classify([FilesystemEvent(path: tree.folder.appendingPathComponent(".git/objects").path)]).isEmpty)
    }

    @Test func topologyChangesAndMissingRootCreationForceDiscovery() {
        for path in [root.path, root.appendingPathComponent("new/App").path, root.deletingLastPathComponent().path] {
            let request = router.classify([FilesystemEvent(path: path)])
            #expect(request.worktrees && request.allProjects)
        }
        let coalesced = router.classify([FilesystemEvent(path: root.path)])
        #expect(coalesced.gitStatusIDs == ["one"])
    }

    @Test func applicationEventsInvalidateOnlyTheCatalog() {
        let request = router.classify([FilesystemEvent(path: "/Applications/New IDE.app")])
        #expect(request.applications)
        #expect(!request.worktrees)
    }

    @Test func similarPrefixesAndCodexConversationEventsAreIgnored() {
        for path in [root.path + "-archive/abc/App", root.deletingLastPathComponent().appendingPathComponent("sessions").path,
                     "/tmp/twig-routing/repo/.github", "/ApplicationsBackup"] {
            #expect(router.classify([FilesystemEvent(path: path)]).isEmpty)
        }
    }

    @Test func droppedEventsAndRenamedRootsRecoverConservatively() {
        let request = router.classify([FilesystemEvent(path: "/", requiresFullRescan: true)])
        #expect(request.worktrees && request.allProjects && request.applications && request.reconfigureWatcher)
    }

    @Test func hiddenChangesWaitAndAreCoalescedUntilPresentation() {
        var state = RefreshState()
        #expect(state.takePending() == nil)
        state.isVisible = true
        #expect(state.takePending() == .full)
        #expect(state.takePending() == nil)
        state.isVisible = false
        state.invalidate(router.classify([FilesystemEvent(path: tree.gitDirectory!.path)]))
        state.invalidate(router.classify([FilesystemEvent(path: tree.folder.appendingPathComponent("Sources").path)]))
        #expect(state.takePending() == nil)
        state.isVisible = true
        let request = state.takePending()
        #expect(request?.worktrees == true)
        #expect(request?.projectIDs == ["one"])
        #expect(request?.allProjects == false)
        // Reopening an unchanged menu and idle time have no pending scan to consume.
        state.isVisible = false
        state.isVisible = true
        #expect(state.takePending() == nil)
    }

    @Test func changesDuringAScanRemainPendingAndManualRefreshCanRunHidden() {
        var state = RefreshState()
        #expect(state.takePending(allowWhileHidden: true) == .full)
        let request = router.classify([FilesystemEvent(path: tree.gitDirectory!.path)])
        state.invalidate(request)
        #expect(state.takePending() == nil)
        #expect(state.takePending(allowWhileHidden: true) == request)
        #expect(state.takePending(allowWhileHidden: true) == nil)
    }

    @Test func rootsAreDeduplicatedAtComponentBoundaries() {
        let roots = FileEventWatcher.minimalRoots([
            URL(fileURLWithPath: "/tmp/watch"), URL(fileURLWithPath: "/tmp/watch/child"),
            URL(fileURLWithPath: "/tmp/watch"), URL(fileURLWithPath: "/tmp/watch-other")
        ])
        #expect(roots.count == 2)
        #expect(roots.contains { $0.path.hasSuffix("/watch-other") })
    }

    @Test func explicitlyAddedCheckoutContentInvalidatesItsOwnDetection() {
        let folder = URL(fileURLWithPath: "/tmp/ordinary/Repo-feature")
        let external = WatchedWorktree(id: "outside", folder: folder,
                                      gitDirectory: URL(fileURLWithPath: "/tmp/ordinary/Repo/.git/worktrees/feature"),
                                      commonGitDirectory: URL(fileURLWithPath: "/tmp/ordinary/Repo/.git"))
        let routing = ChangeRouting(worktreesRoot: root, worktrees: [tree, external], applicationDirectories: [],
                                    repositoryRoots: [URL(fileURLWithPath: "/tmp/ordinary/Repo")])
        let changed = routing.classify([FilesystemEvent(path: folder.appendingPathComponent("Sources").path)])
        #expect(changed.worktrees)
        #expect(changed.projectIDs == ["outside"])
        #expect(!changed.allProjects)
        let dependency = routing.classify([FilesystemEvent(path: folder.appendingPathComponent("node_modules/package").path)])
        #expect(!dependency.worktrees && dependency.gitStatusIDs == ["outside"])
        let removed = routing.classify([FilesystemEvent(path: folder.deletingLastPathComponent().path)])
        #expect(removed.worktrees && removed.reconfigureWatcher)
    }

    @Test func newAndRemovedCommonRegistrationsTriggerDiscoveryAndSubscriptions() {
        for suffix in ["worktrees", "worktrees/new", "worktrees/new/gitdir", "packed-refs"] {
            let request = router.classify([FilesystemEvent(path: tree.commonGitDirectory!.appendingPathComponent(suffix).path)])
            #expect(request.worktrees)
            if suffix.hasPrefix("worktrees") { #expect(request.reconfigureWatcher) }
        }
    }

    @Test func bareRepositoryWithNoCheckoutsStillObservesItsRegistry() {
        let bare = URL(fileURLWithPath: "/tmp/ordinary/Remote.git")
        let routing = ChangeRouting(worktreesRoot: root, worktrees: [], applicationDirectories: [],
                                    repositoryRoots: [bare], repositoryGitDirectories: [bare])
        let request = routing.classify([FilesystemEvent(path: bare.appendingPathComponent("worktrees/new").path)])
        #expect(request.worktrees && request.reconfigureWatcher)
        #expect(routing.classify([FilesystemEvent(path: bare.appendingPathComponent("objects/aa").path)]).isEmpty)
    }

    @Test func unavailableRootReappearanceAndNewGitMetadataTriggerDiscovery() {
        let selected = URL(fileURLWithPath: "/tmp/disconnected/Repo")
        let routing = ChangeRouting(worktreesRoot: root, worktrees: [], applicationDirectories: [], repositoryRoots: [selected])
        for path in [selected.path, selected.deletingLastPathComponent().path, selected.appendingPathComponent(".git/refs").path] {
            let request = routing.classify([FilesystemEvent(path: path)])
            #expect(request.worktrees && request.reconfigureWatcher)
        }
        #expect(routing.classify([FilesystemEvent(path: selected.path + "-backup")]).isEmpty)
    }

    @Test func externalCheckoutFoldersAreIncludedInWatchRoots() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("TwigWatchRoots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let selected = temporary.appendingPathComponent("original")
        let linked = temporary.appendingPathComponent("elsewhere/feature")
        let codex = temporary.appendingPathComponent("codex/worktrees")
        for url in [selected, linked, codex] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        let routing = ChangeRouting(worktreesRoot: codex,
            worktrees: [WatchedWorktree(id: "external", folder: linked)], applicationDirectories: [], repositoryRoots: [selected])
        #expect(routing.watchRoots.contains(linked.standardizedFileURL.resolvingSymlinksInPath()))
        #expect(routing.watchRoots.contains(selected.standardizedFileURL.resolvingSymlinksInPath()))
    }

    @Test func unavailableRegisteredCheckoutIsWatchedUntilItsFolderReturns() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("TwigMissingCheckout-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let original = temporary.appendingPathComponent("repository")
        let externalParent = temporary.appendingPathComponent("external-drive")
        let missing = externalParent.appendingPathComponent("review")
        let codex = temporary.appendingPathComponent("codex/worktrees")
        for folder in [original, externalParent, codex] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        // Store includes unavailable registration paths in repositoryRoots in
        // addition to explicitly configured roots, even with no active row.
        let routing = ChangeRouting(worktreesRoot: codex, worktrees: [], applicationDirectories: [], repositoryRoots: [original, missing])
        #expect(routing.watchRoots.contains(externalParent.standardizedFileURL.resolvingSymlinksInPath()))
        try FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        let request = routing.classify([FilesystemEvent(path: missing.path)])
        #expect(request.worktrees && request.reconfigureWatcher)
        #expect(!request.applications)
    }

    @Test func indexAndUpstreamRefEventsRefreshAffectedSiblingsOnly() {
        let sibling = WatchedWorktree(id: "two", folder: URL(fileURLWithPath: "/tmp/other-checkout"),
            gitDirectory: tree.commonGitDirectory!.appendingPathComponent("worktrees/other"),
            commonGitDirectory: tree.commonGitDirectory)
        let unrelated = WatchedWorktree(id: "three", folder: URL(fileURLWithPath: "/tmp/unrelated"),
            gitDirectory: URL(fileURLWithPath: "/tmp/unrelated/.git"))
        let routing = ChangeRouting(worktreesRoot: root, worktrees: [tree, sibling, unrelated], applicationDirectories: [])
        let refChange = routing.classify([FilesystemEvent(path: tree.commonGitDirectory!.appendingPathComponent("refs/remotes/origin/main").path)])
        #expect(refChange.gitStatusIDs == ["one", "two"])
        #expect(!refChange.allProjects)
        let sourceChange = routing.classify([FilesystemEvent(path: sibling.folder.appendingPathComponent("file.txt").path)])
        #expect(sourceChange.gitStatusIDs == ["two"])
        let indexChange = routing.classify([FilesystemEvent(path: sibling.gitDirectory!.appendingPathComponent("index").path)])
        #expect(indexChange.gitStatusIDs == ["two"])
        #expect(!indexChange.allGitStatuses)
        #expect(!indexChange.reconfigureWatcher)
        let coalesced = routing.classify([FilesystemEvent(path: sibling.gitDirectory!.path)])
        #expect(coalesced.gitStatusIDs == ["two"])
        #expect(!coalesced.allGitStatuses)
        #expect(!coalesced.reconfigureWatcher)
        let registry = routing.classify([FilesystemEvent(path: tree.commonGitDirectory!.appendingPathComponent("worktrees").path)])
        #expect(registry.gitStatusIDs == ["one", "two"])
        #expect(!registry.allGitStatuses)
    }

    @Test func excludeAndAttributeRulesRefreshGitStatus() {
        for suffix in ["info", "info/exclude", "info/attributes"] {
            let request = router.classify([FilesystemEvent(path: tree.commonGitDirectory!.appendingPathComponent(suffix).path)])
            #expect(request.gitStatusIDs == ["one"])
            #expect(!request.allProjects)
        }
    }

    @Test func statusOnlyRequestsCoalesceWhileHiddenAndSurviveInFlightReads() {
        var state = RefreshState()
        _ = state.takePending(allowWhileHidden: true)
        var first = RefreshRequest()
        first.gitStatusIDs = ["one"]
        var second = RefreshRequest()
        second.gitStatusIDs = ["two"]
        state.invalidate(first)
        state.invalidate(second)
        #expect(!state.pending.isEmpty)
        #expect(state.takePending() == nil)
        state.isVisible = true
        #expect(state.takePending()?.gitStatusIDs == ["one", "two"])
        state.invalidate(first)
        #expect(state.takePending()?.gitStatusIDs == ["one"])
        #expect(state.takePending() == nil)
    }
}
