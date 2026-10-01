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

    @Test func dependencyAndBuildEventsDoNotTriggerWork() {
        for relative in ["node_modules/package", ".build/debug", "build/tmp", ".git/objects", "dist/assets", "Pods/Foo"] {
            #expect(router.classify([FilesystemEvent(path: tree.folder.appendingPathComponent(relative).path)]).isEmpty)
        }
    }

    @Test func topologyChangesAndMissingRootCreationForceDiscovery() {
        for path in [root.path, root.appendingPathComponent("new/App").path, root.deletingLastPathComponent().path] {
            let request = router.classify([FilesystemEvent(path: path)])
            #expect(request.worktrees && request.allProjects)
        }
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
}
