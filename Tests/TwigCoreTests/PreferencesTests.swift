import Foundation
import Testing
@testable import TwigCore

@Suite(.serialized)
final class PreferencesTests {
    @Test
    func testPreferencesRoundTripAndRemoval() throws {
        try withStore { store, _ in
            let folder = URL(fileURLWithPath: "/tmp/worktree with spaces")
            var preferences = try store.load()
            preferences.codexHome = "/tmp/custom-codex"
            preferences.fallbackIDE = .zed
            preferences.hasCompletedWelcome = true
            preferences.setOverride(WorktreeOverride(ide: .vscode, targetPath: "app.code-workspace"), for: folder)
            preferences.recordOpened(folder, at: Date(timeIntervalSince1970: 1_700_000_000.123))
            try store.save(preferences)
            let reloaded = try FilePreferencesStore(storageURL: store.storageURL).load()
            #expect(reloaded == preferences)
            preferences.setOverride(nil, for: folder)
            try store.save(preferences)
            #expect(try store.load().overrideForWorktree(folder) == nil)
        }
    }

    @Test
    func testEquivalentPathsShareOverrideAndRecentTime() throws {
        try withStore { _, root in
            let folder = root.appendingPathComponent("worktree", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let alternate = folder.appendingPathComponent("../worktree", isDirectory: true)
            let symbolicLink = root.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: symbolicLink, withDestinationURL: folder)
            var preferences = TwigPreferences()
            preferences.setOverride(WorktreeOverride(ide: .clion), for: alternate)
            let time = Date(timeIntervalSince1970: 10)
            preferences.recordOpened(symbolicLink, at: time)
            #expect(preferences.overrideForWorktree(folder)?.ide == .clion)
            #expect(preferences.overrideForWorktree(symbolicLink)?.ide == .clion)
            #expect(preferences.lastOpenedDate(for: alternate) == time)
            #expect(preferences.overrides.count == 1)
        }
    }

    @Test
    func testCorruptFileIsPreservedUntilExplicitReset() throws {
        try withStore { store, _ in
            let corrupt = Data("not valid JSON".utf8)
            try corrupt.write(to: store.storageURL)
            #expect(throws: (any Error).self) { try store.load() }
            #expect(throws: PreferencesStoreError.resetRequired) {
                try store.save(TwigPreferences())
            }
            #expect(try Data(contentsOf: store.storageURL) == corrupt)
            try store.reset(TwigPreferences(fallbackIDE: .vscode))
            #expect(try store.load().fallbackIDE == .vscode)
        }
    }

    @Test
    func testSaveWithoutLoadAlsoPreservesCorruptExistingFile() throws {
        try withStore { store, _ in
            let corrupt = Data("{".utf8)
            try corrupt.write(to: store.storageURL)
            #expect(throws: (any Error).self) { try store.save(TwigPreferences()) }
            #expect(try Data(contentsOf: store.storageURL) == corrupt)
        }
    }

    @Test
    func testFutureFormatFailsWithoutBeingOverwritten() throws {
        try withStore { store, _ in
            let future = Data("{\"schemaVersion\":999}".utf8)
            try future.write(to: store.storageURL)
            #expect(throws: PreferencesStoreError.unsupportedVersion(999)) {
                try store.load()
            }
            #expect(throws: (any Error).self) { try store.save(TwigPreferences()) }
            #expect(try Data(contentsOf: store.storageURL) == future)
        }
    }

    @Test
    func testMissingOptionalFieldsUseDefaults() throws {
        try withStore { store, _ in
            try Data("{\"schemaVersion\":1}".utf8).write(to: store.storageURL)
            #expect(try store.load() == TwigPreferences())
            #expect(try store.load().sortOrder == .activity)
        }
    }

    @Test
    func testNewStoreCreatesParentDirectoryOnSave() throws {
        try withStore { _, root in
            let store = FilePreferencesStore(storageURL: root.appendingPathComponent("nested/preferences.json"))
            let preferences = TwigPreferences(fallbackIDE: .cursor)
            try store.save(preferences)
            #expect(try store.load() == preferences)
        }
    }

    @Test
    func testPinsLabelsAndSortOrderRoundTrip() throws {
        try withStore { store, root in
            let folder = root.appendingPathComponent("worktree")
            let alternate = folder.appendingPathComponent("../worktree")
            var preferences = TwigPreferences()
            preferences.setPinned(true, for: alternate)
            preferences.setLabel("  Login   redesign\n", for: folder)
            preferences.sortOrder = .project
            try store.save(preferences)
            let reloaded = try store.load()
            #expect(reloaded.isPinned(folder))
            #expect(reloaded.label(for: alternate) == "Login redesign")
            #expect(reloaded.sortOrder == .project)
            #expect(reloaded == preferences)

            preferences.setPinned(false, for: folder)
            preferences.setLabel(" \n\t", for: alternate)
            try store.save(preferences)
            #expect(try store.load().pinnedWorktrees.isEmpty)
            #expect(try store.load().worktreeLabels.isEmpty)
        }
    }

    @Test(arguments: WorktreeSortOrder.allCases)
    func testSortOrderPersistsWithLegacyCompatibility(sortOrder: WorktreeSortOrder) throws {
        try withStore { store, _ in
            let preferences = TwigPreferences(sortOrder: sortOrder)
            try store.save(preferences)
            #expect(try FilePreferencesStore(storageURL: store.storageURL).load() == preferences)
            let encoded = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: store.storageURL)) as? [String: Any])
            #expect(encoded["sortOrder"] as? String == sortOrder.rawValue)
            #expect(encoded["groupByRepository"] as? Bool == (sortOrder == .project))
            #expect(encoded["schemaVersion"] as? Int == 1)
        }
    }

    @Test(arguments: [false, true])
    func testLegacyGroupingMigratesToSortOrder(grouped: Bool) throws {
        try withStore { store, _ in
            let legacy = Data("{\"schemaVersion\":1,\"groupByRepository\":\(grouped)}".utf8)
            try legacy.write(to: store.storageURL)
            let preferences = try store.load()
            #expect(preferences == TwigPreferences(sortOrder: grouped ? .project : .activity))
            try store.save(preferences)
            #expect(try FilePreferencesStore(storageURL: store.storageURL).load() == preferences)
        }
    }

    @Test(arguments: WorktreeSortOrder.allCases)
    func testExplicitSortOrderWinsOverLegacyGrouping(sortOrder: WorktreeSortOrder) throws {
        try withStore { store, _ in
            let preferences = Data("{\"schemaVersion\":1,\"sortOrder\":\"\(sortOrder.rawValue)\",\"groupByRepository\":\(sortOrder == .activity)}".utf8)
            try preferences.write(to: store.storageURL)
            #expect(try store.load().sortOrder == sortOrder)
        }
    }

    @Test
    func testUnknownSortOrderFallsBackWithoutDiscardingPreferences() throws {
        try withStore { store, root in
            let folder = root.appendingPathComponent("worktree")
            var expected = TwigPreferences(codexHome: "/tmp/custom-codex", fallbackIDE: .zed,
                                           sortOrder: .activity, hasCompletedWelcome: true,
                                           globalShortcut: nil, repositoryRoots: ["/projects/Atlas"])
            expected.setPinned(true, for: folder)
            expected.setLabel("Login redesign", for: folder)
            expected.setOverride(WorktreeOverride(ide: .vscode, targetPath: "app.code-workspace"), for: folder)
            expected.recordOpened(folder, at: Date(timeIntervalSince1970: 1_700_000_000))
            try store.save(expected)
            var future = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: store.storageURL)) as? [String: Any])
            future["sortOrder"] = "future-order"
            future["groupByRepository"] = true
            try JSONSerialization.data(withJSONObject: future).write(to: store.storageURL)
            let reloaded = try FilePreferencesStore(storageURL: store.storageURL).load()
            #expect(reloaded == expected)
            try store.save(reloaded)
            #expect(try store.load() == expected)
        }
    }

    @Test
    func testRepositoryRootsPersistEvenWhenUnavailable() throws {
        try withStore { store, root in
            var preferences = TwigPreferences()
            preferences.repositoryRoots = [root.appendingPathComponent("missing-drive/Repo").path, "/tmp/second-repository"]
            try store.save(preferences)
            #expect(try store.load().repositoryRoots == preferences.repositoryRoots)
        }
    }

    private func withStore(_ body: (FilePreferencesStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigPreferencesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(FilePreferencesStore(storageURL: root.appendingPathComponent("preferences.json")), root)
    }
}
