import Foundation
import Testing
@testable import TwigCore

struct RepositoryDiscoveryTests {
    @Test func mainAndAllLinkedCheckoutsAreDiscoveredFromEitherEntryPoint() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        let one = try fixture.linked("search", branch: "feature/search")
        let two = try fixture.linked("review", branch: nil)
        for entry in [fixture.main, one] {
            let result = RepositoryDiscoverer().discover(at: entry)
            #expect(result.status.isAvailable)
            #expect(result.status.worktreeCount == 3)
            #expect(result.warnings.isEmpty)
            #expect(Set(result.worktrees.map { $0.folder.path }) == [fixture.main.path, one.path, two.path])
            #expect(Set(result.worktrees.map(\.repositoryName)) == ["Original"])
            let detached = try #require(result.worktrees.first { $0.folder.path == two.path })
            #expect(detached.branch == nil)
        }
    }

    @Test func relativePointersAreResolvedFromTheirOwnMetadataLocations() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        let linked = try fixture.linked("relative", branch: "feature/relative")
        let admin = fixture.common.appendingPathComponent("worktrees/relative")
        try fixture.write("gitdir: ../../Original/.git/worktrees/relative\n", to: linked.appendingPathComponent(".git"))
        try fixture.write("../../../../branches/relative/.git\n", to: admin.appendingPathComponent("gitdir"))
        let result = RepositoryDiscoverer().discover(at: linked)
        #expect(result.warnings.isEmpty)
        #expect(result.worktrees.count == 2)
    }

    @Test func bareRepositoryExposesOnlyItsLinkedCheckouts() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        let bare = fixture.root.appendingPathComponent("Remote.git")
        try fixture.write("ref: refs/heads/main", to: bare.appendingPathComponent("HEAD"))
        try fixture.write(RepositoryFixture.revision, to: bare.appendingPathComponent("refs/heads/main"))
        try FileManager.default.createDirectory(at: bare.appendingPathComponent("objects"), withIntermediateDirectories: true)
        let empty = RepositoryDiscoverer().discover(at: bare)
        #expect(empty.status.isAvailable)
        #expect(empty.worktrees.isEmpty)
        let folder = try fixture.linked("bare-review", branch: nil, common: bare)
        let result = RepositoryDiscoverer().discover(at: bare)
        #expect(result.status.isAvailable)
        #expect(result.worktrees.map { $0.folder.path } == [folder.path])
        #expect(result.worktrees.first?.repositoryName == "Remote")
    }

    @Test func staleAndMisdirectedRegistrationsDoNotHideValidCheckouts() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        let valid = try fixture.linked("valid", branch: "valid")
        let missing = try fixture.linked("gone", branch: "gone")
        try FileManager.default.removeItem(at: missing)
        let misplaced = fixture.common.appendingPathComponent("worktrees/misdirected")
        try fixture.write(valid.appendingPathComponent(".git").path, to: misplaced.appendingPathComponent("gitdir"))
        let result = RepositoryDiscoverer().discover(at: fixture.main)
        #expect(result.status.isAvailable)
        #expect(result.worktrees.count == 2)
        #expect(result.warnings.count == 2)
    }

    @Test func unavailableRootReportsActionableStatusAndCanReturn() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        let moved = fixture.root.appendingPathComponent("temporarily-away")
        try FileManager.default.moveItem(at: fixture.main, to: moved)
        let unavailable = RepositoryDiscoverer().discover(at: fixture.main)
        #expect(!unavailable.status.isAvailable)
        #expect(unavailable.status.root == fixture.main)
        #expect(unavailable.status.message?.contains("Reconnect") == true)
        try FileManager.default.moveItem(at: moved, to: fixture.main)
        #expect(RepositoryDiscoverer().discover(at: fixture.main).status.isAvailable)
    }

    @Test func ordinaryFoldersAndSymlinkedMetadataAreRejected() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        #expect(!RepositoryDiscoverer().discover(at: fixture.root).status.isAvailable)
        let head = fixture.common.appendingPathComponent("HEAD")
        try FileManager.default.removeItem(at: head)
        let external = fixture.root.appendingPathComponent("external-head")
        try fixture.write(RepositoryFixture.revision, to: external)
        try FileManager.default.createSymbolicLink(at: head, withDestinationURL: external)
        #expect(!RepositoryDiscoverer().discover(at: fixture.main).status.isAvailable)
    }

    @Test func codexAndExplicitRootsDeduplicateCanonicalCheckouts() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        let codex = fixture.root.appendingPathComponent("codex")
        let shared = codex.appendingPathComponent("worktrees/session/Original")
        _ = try fixture.linked("shared", branch: "shared", folder: shared)
        let alias = fixture.root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.main)
        let result = WorktreeCatalog().discover(codexHome: codex, repositoryRoots: [fixture.main, alias, shared])
        #expect(result.worktrees.count == 2)
        #expect(Set(result.worktrees.map(\.id)).count == 2)
        #expect(result.repositoryStatuses.count == 2)
    }

    @Test func addedAndRemovedDiscoverySourcesPreserveAndPruneInferenceCache() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        _ = try fixture.linked("one", branch: "one")
        let scanner = WorktreeScanner()
        let codex = fixture.root.appendingPathComponent("codex")
        #expect(await scanner.scan(codexHome: codex).items.isEmpty)
        let added = await scanner.scan(codexHome: codex, invalidatedWorktrees: [], repositoryRoots: [fixture.main])
        #expect(added.items.count == 2)
        #expect(added.detectionsPerformed == 2)
        #expect(added.repositoryStatuses.first?.worktreeCount == 2)
        #expect(await scanner.scan(codexHome: codex, invalidatedWorktrees: [], repositoryRoots: [fixture.main]).detectionsPerformed == 0)
        #expect(await scanner.scan(codexHome: codex, invalidatedWorktrees: []).items.isEmpty)
        #expect(await scanner.scan(codexHome: codex, invalidatedWorktrees: [], repositoryRoots: [fixture.main]).detectionsPerformed == 2)
    }

    @Test func sameNamedRepositoriesRemainIndependentSources() throws {
        let first = try RepositoryFixture(), second = try RepositoryFixture()
        defer { first.remove(); second.remove() }
        let result = WorktreeCatalog().discover(codexHome: first.root.appendingPathComponent("codex"), repositoryRoots: [first.main, second.main])
        #expect(result.worktrees.count == 2)
        #expect(result.repositoryStatuses.count == 2)
        #expect(Set(result.worktrees.compactMap { $0.commonGitDirectory?.path }).count == 2)
    }
}

private struct RepositoryFixture {
    static let revision = String(repeating: "a", count: 40)
    let root: URL
    var main: URL { root.appendingPathComponent("Original") }
    var common: URL { main.appendingPathComponent(".git") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigRepository-\(UUID().uuidString)").standardizedFileURL.resolvingSymlinksInPath()
        try write("ref: refs/heads/main\n", to: common.appendingPathComponent("HEAD"))
        try write(Self.revision, to: common.appendingPathComponent("refs/heads/main"))
        try FileManager.default.createDirectory(at: common.appendingPathComponent("objects"), withIntermediateDirectories: true)
    }

    func linked(_ id: String, branch: String?, common: URL? = nil, folder: URL? = nil) throws -> URL {
        let metadata = common ?? self.common
        let checkout = folder ?? root.appendingPathComponent("branches/\(id)")
        let admin = metadata.appendingPathComponent("worktrees/\(id)")
        try write("gitdir: \(admin.path)\n", to: checkout.appendingPathComponent(".git"))
        try write(branch.map { "ref: refs/heads/\($0)\n" } ?? Self.revision, to: admin.appendingPathComponent("HEAD"))
        try write("../..\n", to: admin.appendingPathComponent("commondir"))
        try write(checkout.appendingPathComponent(".git").path, to: admin.appendingPathComponent("gitdir"))
        if let branch { try write(Self.revision, to: metadata.appendingPathComponent("refs/heads/\(branch)")) }
        return checkout
    }

    func write(_ value: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try value.write(to: url, atomically: true, encoding: .utf8)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
