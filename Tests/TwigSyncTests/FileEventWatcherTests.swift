import Foundation
import Testing
@testable import TwigSync

@Suite(.serialized)
struct FileEventWatcherTests {
    @Test func observesRealDirectoryChangesAndRoutesLinkedGitChanges() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let checkout = root.appendingPathComponent("codex/worktrees/abc/App")
        let git = root.appendingPathComponent("repository/.git/worktrees/App")
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        let watcher = FileEventWatcher()
        defer { watcher.stop() }
        let (events, continuation) = AsyncStream<FilesystemEvent>.makeStream()
        defer { continuation.finish() }
        try watcher.start(paths: [checkout, git], latency: 0.1) { batch in
            for event in batch { continuation.yield(event) }
        }
        try Data("ref: refs/heads/switched\n".utf8).write(to: git.appendingPathComponent("HEAD"))
        let router = ChangeRouting(worktreesRoot: root.appendingPathComponent("codex/worktrees"),
                                   worktrees: [WatchedWorktree(id: "App", folder: checkout, gitDirectory: git)],
                                   applicationDirectories: [])
        let received = await firstRelevantEvent(events, root: git)
        #expect(received != nil, "FSEvents must deliver a linked-worktree metadata change")
        if let received {
            let invalidation = router.classify([received])
            #expect(invalidation.worktrees)
            #expect(invalidation.projectIDs.isEmpty)
        }
    }

    @Test func watchingAMissingRootThroughItsParentSeesCreation() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appendingPathComponent("new/codex/worktrees")
        let parent = FileEventWatcher.existingWatchRoot(for: missing)
        #expect(parent.path == root.path)
        let watcher = FileEventWatcher()
        defer { watcher.stop() }
        let (events, continuation) = AsyncStream<FilesystemEvent>.makeStream()
        defer { continuation.finish() }
        try watcher.start(paths: [parent], latency: 0.1) { batch in
            for event in batch { continuation.yield(event) }
        }
        try FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        let received = await firstRelevantEvent(events, root: root)
        #expect(received != nil, "Creation below a missing configured root must be detected")
        if let received {
            let router = ChangeRouting(worktreesRoot: missing, worktrees: [], applicationDirectories: [])
            #expect(router.classify([received]).worktrees)
        }
    }

    @Test func canStopAndReplaceTheWatchedRoots() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first"), second = root.appendingPathComponent("second")
        for folder in [first, second] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let watcher = FileEventWatcher()
        defer { watcher.stop() }
        try watcher.start(paths: [first], latency: 0.1) { _ in }
        watcher.stop()
        let (events, continuation) = AsyncStream<FilesystemEvent>.makeStream()
        defer { continuation.finish() }
        try watcher.start(paths: [second], latency: 0.1) { batch in
            for event in batch { continuation.yield(event) }
        }
        try Data("change".utf8).write(to: second.appendingPathComponent("source.swift"))
        #expect(await firstRelevantEvent(events, root: second) != nil)
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigWatch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func firstRelevantEvent(_ events: AsyncStream<FilesystemEvent>, root: URL) async -> FilesystemEvent? {
        await withTaskGroup(of: FilesystemEvent?.self) { group in
            group.addTask {
                for await event in events where isWithin(canonicalPath(event.path), root: canonicalPath(root.path)) {
                    return event
                }
                return nil
            }
            group.addTask { try? await Task.sleep(for: .seconds(5)); return nil }
            let event = await group.next() ?? nil
            group.cancelAll()
            return event
        }
    }
}
