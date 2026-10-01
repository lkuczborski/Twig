import Foundation
import Testing
@testable import TwigCore

struct WorktreeScannerTests {
    @Test func metadataRefreshReusesInferenceButAnAffectedProjectIsRechecked() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let folder = try checkout("first/App", in: home)
        try Data("// Swift package\n".utf8).write(to: folder.appendingPathComponent("Package.swift"))
        let scanner = WorktreeScanner()
        let initial = await scanner.scan(codexHome: home)
        #expect(initial.detectionsPerformed == 1)
        let id = try #require(initial.items.first?.id)
        #expect(initial.items.first?.detection.candidates.first?.ide == .xcode)

        try Data(String(repeating: "a", count: 40).utf8).write(to: folder.appendingPathComponent(".git/HEAD"))
        try Data("{}".utf8).write(to: folder.appendingPathComponent("App.code-workspace"))
        let metadata = await scanner.scan(codexHome: home, invalidatedWorktrees: [])
        #expect(metadata.detectionsPerformed == 0)
        #expect(metadata.items.first?.worktree.branch == nil)
        #expect(metadata.items.first?.detection.candidates.first?.ide == .xcode)

        let affected = await scanner.scan(codexHome: home, invalidatedWorktrees: [id])
        #expect(affected.detectionsPerformed == 1)
        #expect(affected.items.first?.detection.candidates.first?.ide == .vscode)
    }

    @Test func newAndRemovedCheckoutsDoNotLeaveStaleCacheEntries() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let first = try checkout("one/App", in: home)
        let scanner = WorktreeScanner()
        #expect(await scanner.scan(codexHome: home).detectionsPerformed == 1)
        _ = try checkout("two/Other", in: home)
        let added = await scanner.scan(codexHome: home, invalidatedWorktrees: [])
        #expect(added.items.count == 2)
        #expect(added.detectionsPerformed == 1)
        try FileManager.default.removeItem(at: first)
        #expect(await scanner.scan(codexHome: home, invalidatedWorktrees: []).items.count == 1)
        let recreated = try checkout("one/App", in: home)
        try Data("{}".utf8).write(to: recreated.appendingPathComponent("Web.code-workspace"))
        let returned = await scanner.scan(codexHome: home, invalidatedWorktrees: [])
        #expect(returned.detectionsPerformed == 1)
        #expect(returned.items.first { $0.worktree.repositoryName == "App" }?.detection.candidates.first?.ide == .vscode)
    }

    @Test func changingCodexHomeAndManualRefreshDiscardInference() async throws {
        let one = try fixture(), two = try fixture()
        defer { try? FileManager.default.removeItem(at: one); try? FileManager.default.removeItem(at: two) }
        _ = try checkout("one/App", in: one)
        _ = try checkout("two/Other", in: two)
        let scanner = WorktreeScanner()
        #expect(await scanner.scan(codexHome: one).detectionsPerformed == 1)
        #expect(await scanner.scan(codexHome: one, invalidatedWorktrees: []).detectionsPerformed == 0)
        #expect(await scanner.scan(codexHome: one).detectionsPerformed == 1)
        #expect(await scanner.scan(codexHome: two, invalidatedWorktrees: []).detectionsPerformed == 1)
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigScan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL.resolvingSymlinksInPath()
    }
    private func checkout(_ name: String, in home: URL) throws -> URL {
        let folder = home.appendingPathComponent("worktrees/" + name)
        let git = folder.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: git.appendingPathComponent("refs/heads"), withIntermediateDirectories: true)
        try Data("ref: refs/heads/main\n".utf8).write(to: git.appendingPathComponent("HEAD"))
        try Data(String(repeating: "1", count: 40).utf8).write(to: git.appendingPathComponent("refs/heads/main"))
        return folder
    }
}
