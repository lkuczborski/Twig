import Foundation
import Testing
@testable import TwigCore

struct WorktreeDiscoveryTests {
    @Test func missingRootIsEmptyWithoutWarnings() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test func discoversBranchFromGitMetadataAndCanonicalPath() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let checkout = try fixture.checkout("abcd", name: "A Project", head: "ref: refs/heads/codex/a-feature")
        try fixture.write(Fixture.revision, to: fixture.common.appendingPathComponent("refs/heads/codex/a-feature"))

        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        let worktree = try #require(result.worktrees.first)
        #expect(result.warnings.isEmpty)
        #expect(result.worktrees.count == 1)
        #expect(worktree.id == checkout.folder.resolvingSymlinksInPath().path)
        #expect(worktree.folder == checkout.folder.resolvingSymlinksInPath())
        #expect(worktree.repositoryName == "A Project")
        #expect(worktree.branch == "codex/a-feature")
        #expect(worktree.headRevision == Fixture.revision)
    }

    @Test func preservesDetachedHEAD() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = try fixture.checkout("detached", head: Fixture.revision)
        let worktree = try #require(WorktreeDiscoverer().discover(in: fixture.codexHome).worktrees.first)
        #expect(worktree.branch == nil)
        #expect(worktree.headRevision == Fixture.revision)
    }

    @Test func resolvesPackedRefsAndUnbornBranches() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = try fixture.checkout("packed", head: "ref: refs/heads/release")
        _ = try fixture.checkout("unborn", head: "ref: refs/heads/new")
        try fixture.write("# pack-refs with: peeled fully-peeled sorted\n\(Fixture.revision) refs/heads/release\n^\(Fixture.otherRevision)\n", to: fixture.common.appendingPathComponent("packed-refs"))
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.warnings.isEmpty)
        #expect(result.worktrees.first { $0.branch == "release" }?.headRevision == Fixture.revision)
        let unborn = try #require(result.worktrees.first { $0.branch == "new" })
        #expect(unborn.headRevision == nil)
    }

    @Test func looseRefWinsOverPackedRefAndFollowsBranchChanges() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let checkout = try fixture.checkout("live", head: "ref: refs/heads/first")
        try fixture.write("\(Fixture.otherRevision) refs/heads/first\n", to: fixture.common.appendingPathComponent("packed-refs"))
        try fixture.write(Fixture.revision, to: fixture.common.appendingPathComponent("refs/heads/first"))
        #expect(WorktreeDiscoverer().discover(in: fixture.codexHome).worktrees.first?.headRevision == Fixture.revision)
        try fixture.write("ref: refs/heads/second", to: checkout.admin.appendingPathComponent("HEAD"))
        #expect(WorktreeDiscoverer().discover(in: fixture.codexHome).worktrees.first?.branch == "second")
    }

    @Test func supportsRelativeGitDirectoryPointers() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let checkout = try fixture.checkout("relative", head: Fixture.revision)
        // Keep the admin directory next to the checkout to exercise a relative pointer.
        let localAdmin = checkout.folder.deletingLastPathComponent().appendingPathComponent("metadata")
        try FileManager.default.moveItem(at: checkout.admin, to: localAdmin)
        try fixture.write("gitdir: ../metadata", to: checkout.folder.appendingPathComponent(".git"))
        try fixture.write(fixture.common.path, to: localAdmin.appendingPathComponent("commondir"))
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.warnings.isEmpty)
        #expect(result.worktrees.count == 1)
    }

    @Test func skipsStalePointersAndMalformedMetadataButKeepsValidWorktrees() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let stale = try fixture.checkout("stale", head: Fixture.revision)
        try FileManager.default.removeItem(at: stale.admin)
        let malformed = try fixture.checkout("bad", head: "ref: refs/heads/../../private")
        _ = malformed
        let backlink = try fixture.checkout("backlink", head: Fixture.revision)
        try fixture.write("/a/different/checkout/.git", to: backlink.admin.appendingPathComponent("gitdir"))
        _ = try fixture.checkout("valid", head: Fixture.revision)
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.count == 1)
        #expect(result.worktrees.first?.folder.deletingLastPathComponent().lastPathComponent == "valid")
        #expect(result.warnings.count == 3)
    }

    @Test func ignoresDirectoriesWithoutGitMetadataAndSymlinkedCheckouts() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let checkout = try fixture.checkout("real", head: Fixture.revision)
        let aliasGroup = fixture.codexHome.appendingPathComponent("worktrees/alias")
        try FileManager.default.createDirectory(at: aliasGroup, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasGroup.appendingPathComponent("Repo"), withDestinationURL: checkout.folder)
        try FileManager.default.createSymbolicLink(at: fixture.codexHome.appendingPathComponent("worktrees/groupAlias"), withDestinationURL: checkout.folder.deletingLastPathComponent())
        try FileManager.default.createDirectory(at: fixture.codexHome.appendingPathComponent("worktrees/empty/Repo"), withIntermediateDirectories: true)
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.count == 1)
        #expect(result.warnings.isEmpty)
    }

    @Test func skipsSymlinkedHEADAndOversizedMetadata() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let linked = try fixture.checkout("linked", head: Fixture.revision)
        try FileManager.default.removeItem(at: linked.admin.appendingPathComponent("HEAD"))
        let externalHead = fixture.root.appendingPathComponent("external-head")
        try fixture.write(Fixture.revision, to: externalHead)
        try FileManager.default.createSymbolicLink(at: linked.admin.appendingPathComponent("HEAD"), withDestinationURL: externalHead)
        let oversized = try fixture.checkout("oversized", head: Fixture.revision)
        try fixture.write(String(repeating: "a", count: 20_000), to: oversized.folder.appendingPathComponent(".git"))
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.isEmpty)
        #expect(result.warnings.count == 2)
    }

    @Test func sortsByObservedActivityAndIgnoresDependencyFilesAndExternalSymlinks() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let older = try fixture.checkout("older", head: Fixture.revision)
        let newer = try fixture.checkout("newer", head: Fixture.revision)
        let oldDate = Date(timeIntervalSince1970: 1_600_000_000)
        let newDate = oldDate.addingTimeInterval(1_000)
        let dependency = older.folder.appendingPathComponent("node_modules/dependency/index.js")
        let source = newer.folder.appendingPathComponent("Sources/App/Feature.swift")
        try fixture.write("", to: dependency)
        try fixture.write("", to: source)
        let external = fixture.root.appendingPathComponent("outside-file")
        try fixture.write("", to: external)
        try FileManager.default.createSymbolicLink(at: older.folder.appendingPathComponent("linked.swift"), withDestinationURL: external)
        try fixture.setAllDates(oldDate)
        try fixture.setDate(newDate, at: source)
        try fixture.setDate(newDate.addingTimeInterval(5_000), at: dependency)
        try fixture.setDate(newDate.addingTimeInterval(10_000), at: external)
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.count == 2)
        #expect(result.worktrees[0].folder == newer.folder.resolvingSymlinksInPath())
        #expect(result.worktrees[0].lastActivity == newDate)
        #expect(result.worktrees[1].lastActivity == oldDate)
    }

    @Test func gitActivityIsUsedWithoutReadingConversationMetadata() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let checkout = try fixture.checkout("activity", head: Fixture.revision)
        // Invalid text proves that recency only stats these files.
        let threadMetadata = checkout.admin.appendingPathComponent("codex-thread.json")
        try fixture.write("not JSON; never parse this as a conversation", to: threadMetadata)
        let oldDate = Date(timeIntervalSince1970: 1_600_000_000)
        let newDate = oldDate.addingTimeInterval(1_000)
        try fixture.setAllDates(oldDate)
        try fixture.setDate(newDate, at: threadMetadata)
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.warnings.isEmpty)
        #expect(result.worktrees.first?.lastActivity == newDate)
    }

    @Test func supportsDirectCheckoutAndSHA256Revision() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let directory = fixture.codexHome.appendingPathComponent("worktrees/direct/.git")
        let revision = String(repeating: "b", count: 64)
        try fixture.write(revision, to: directory.appendingPathComponent("HEAD"))
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.warnings.isEmpty)
        #expect(result.worktrees.first?.repositoryName == "direct")
        #expect(result.worktrees.first?.headRevision == revision)
    }

    @Test func rejectsCyclicSymbolicReferences() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = try fixture.checkout("cycle", head: "ref: refs/heads/a")
        try fixture.write("ref: refs/heads/b", to: fixture.common.appendingPathComponent("refs/heads/a"))
        try fixture.write("ref: refs/heads/a", to: fixture.common.appendingPathComponent("refs/heads/b"))
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.isEmpty)
        #expect(result.warnings.count == 1)
    }

    @Test func rejectsReferenceDirectoriesThatCrossSymlinks() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = try fixture.checkout("linked-ref", head: "ref: refs/heads/main")
        let external = fixture.root.appendingPathComponent("outside-refs")
        try fixture.write(Fixture.revision, to: external.appendingPathComponent("main"))
        let refs = fixture.common.appendingPathComponent("refs")
        try FileManager.default.createDirectory(at: refs, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: refs.appendingPathComponent("heads"), withDestinationURL: external)
        let result = WorktreeDiscoverer().discover(in: fixture.codexHome)
        #expect(result.worktrees.isEmpty)
        #expect(result.warnings.count == 1)
    }
}

private struct Fixture {
    static let revision = String(repeating: "a", count: 40)
    static let otherRevision = String(repeating: "b", count: 40)
    let root: URL
    var codexHome: URL { root.appendingPathComponent("codex") }
    var common: URL { root.appendingPathComponent("original/.git") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("twig-discovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func checkout(_ identifier: String, name: String = "Repo", head: String) throws -> (folder: URL, admin: URL) {
        let folder = codexHome.appendingPathComponent("worktrees/\(identifier)/\(name)", isDirectory: true)
        let admin = common.appendingPathComponent("worktrees/\(identifier)", isDirectory: true)
        try write("gitdir: \(admin.path)\n", to: folder.appendingPathComponent(".git"))
        try write(head + "\n", to: admin.appendingPathComponent("HEAD"))
        try write("../..\n", to: admin.appendingPathComponent("commondir"))
        try write(folder.appendingPathComponent(".git").path + "\n", to: admin.appendingPathComponent("gitdir"))
        return (folder, admin)
    }

    func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func setDate(_ date: Date, at url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func setAllDates(_ date: Date) throws {
        let entries = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey]))
        for case let url as URL in entries {
            if (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true { try setDate(date, at: url) }
        }
        try setDate(date, at: root)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
