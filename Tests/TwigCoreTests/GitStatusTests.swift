import Foundation
import Testing
@testable import TwigCore

struct GitStatusTests {
    @Test func realRepositoryCountsDistinctPathsAndIgnoresIgnoredFiles() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("base", to: "both.txt")
        try repo.write("ignored/\n", to: ".gitignore")
        try repo.commitAll()
        try repo.write("staged", to: "both.txt")
        try repo.git(["add", "both.txt"])
        try repo.write("unstaged", to: "both.txt")
        try repo.write("one", to: "new folder/one\nname")
        try repo.write("two", to: "new folder/two")
        try repo.write("ignore", to: "ignored/file")
        let status = try repo.status()
        #expect(status.changedFileCount == 3)
        #expect(status.conflictedFileCount == 0)
        #expect(status.aheadCount == nil)
        #expect(status.behindCount == nil)
    }

    @Test func stagedRenameWithUnstagedEditCountsOnce() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("original\n", to: "before")
        try repo.commitAll()
        try repo.git(["mv", "before", "after\nwith space"])
        try repo.write("extra\n", to: "after\nwith space")
        #expect(try repo.status().changedFileCount == 1)
    }

    @Test func conflictCountsAsOneChangedAndOneConflictedPath() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("base\n", to: "conflict")
        try repo.commitAll()
        try repo.git(["checkout", "-b", "other"])
        try repo.write("other\n", to: "conflict")
        try repo.commitAll()
        try repo.git(["checkout", "main"])
        try repo.write("main\n", to: "conflict")
        try repo.commitAll()
        try repo.git(["merge", "other"], expected: 1)
        let status = try repo.status()
        #expect(status.changedFileCount == 1)
        #expect(status.conflictedFileCount == 1)
    }

    @Test func divergenceUsesLocalUpstreamAndMissingUpstreamStaysUnknown() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("base", to: "base")
        try repo.commitAll()
        try repo.git(["checkout", "-b", "upstream"])
        try repo.write("behind", to: "behind")
        try repo.commitAll()
        try repo.git(["checkout", "main"])
        try repo.write("ahead", to: "ahead")
        try repo.commitAll()
        try repo.git(["branch", "--set-upstream-to=upstream", "main"])
        let status = try repo.status()
        #expect(status.aheadCount == 1)
        #expect(status.behindCount == 1)
        try repo.git(["branch", "-D", "upstream"])
        let missing = try repo.status()
        #expect(missing.aheadCount == nil)
        #expect(missing.behindCount == nil)
    }

    @Test func unbornAndDetachedBranchesHaveNoDivergence() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        let unborn = try repo.status()
        #expect(unborn.changedFileCount == 0)
        #expect(unborn.aheadCount == nil)
        try repo.write("first", to: "first")
        #expect(try repo.status().changedFileCount == 1)
        try repo.commitAll()
        try repo.git(["checkout", "--detach"])
        let detached = try repo.status()
        #expect(detached.changedFileCount == 0)
        #expect(detached.aheadCount == nil)
        #expect(detached.behindCount == nil)
    }

    @Test func linkedWorktreeReadsItsOwnIndexAndBranch() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("base", to: "base")
        try repo.commitAll()
        let linked = repo.root.appendingPathComponent("linked with space")
        try repo.git(["worktree", "add", "-b", "linked", linked.path])
        try Data("new".utf8).write(to: linked.appendingPathComponent("new"))
        #expect(GitStatusReader().read(at: linked) == .available(.init(changedFileCount: 1, conflictedFileCount: 0, aheadCount: nil, behindCount: nil)))
        #expect(try repo.status().changedFileCount == 0)
    }

    @Test func hooksFsmonitorAndUnusedFiltersDoNotExecuteOrModifyIndex() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("base", to: "base")
        try repo.commitAll()
        let marker = repo.root.appendingPathComponent("executed")
        let command = "/usr/bin/touch '" + marker.path + "'"
        try repo.git(["config", "core.fsmonitor", command])
        try repo.git(["config", "filter.unused.clean", command])
        try repo.git(["config", "filter.unused.process", command])
        try repo.git(["config", "filter.unused.required", "true"])
        try repo.write("#!/bin/sh\n" + command + "\n", to: ".git/hooks/post-index-change")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: repo.directory.appendingPathComponent(".git/hooks/post-index-change").path)
        try repo.write("changed", to: "base")
        let index = repo.directory.appendingPathComponent(".git/index")
        let before = try Data(contentsOf: index)
        let beforeDate = try FileManager.default.attributesOfItem(atPath: index.path)[.modificationDate] as? Date
        #expect(try repo.status().changedFileCount == 1)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        #expect(try Data(contentsOf: index) == before)
        #expect(try FileManager.default.attributesOfItem(atPath: index.path)[.modificationDate] as? Date == beforeDate)
    }

    @Test func filteredTrackedFilesAreUnavailableWithoutRunningFilter() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        try repo.write("*.filtered filter=custom\n", to: ".gitattributes")
        try repo.write("base", to: "file.filtered")
        try repo.commitAll()
        let marker = repo.root.appendingPathComponent("executed")
        try repo.git(["config", "filter.custom.clean", "/usr/bin/touch '" + marker.path + "'"])
        try repo.git(["config", "filter.custom.required", "true"])
        try repo.write("changed", to: "file.filtered")
        #expect(GitStatusReader().read(at: repo.directory) == .unavailable)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func submoduleDirtyFilesAreExcludedButChangedCommitCounts() throws {
        let repo = try StatusRepository()
        let sub = try StatusRepository()
        defer { repo.remove(); sub.remove() }
        try sub.write("base", to: "base")
        try sub.commitAll()
        try repo.git(["-c", "protocol.file.allow=always", "submodule", "add", sub.directory.path, "nested"])
        try repo.commitAll()
        let nested = repo.directory.appendingPathComponent("nested")
        let marker = repo.root.appendingPathComponent("submodule-executed")
        try repo.git(["-C", nested.path, "config", "core.fsmonitor", "/usr/bin/touch '" + marker.path + "'"])
        try Data("dirty".utf8).write(to: nested.appendingPathComponent("base"))
        try Data("untracked".utf8).write(to: nested.appendingPathComponent("extra"))
        #expect(try repo.status().changedFileCount == 0)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        try repo.git(["-C", nested.path, "-c", "core.fsmonitor=false", "add", "base"])
        try repo.git(["-C", nested.path, "-c", "core.fsmonitor=false", "commit", "-m", "submodule commit"])
        #expect(try repo.status().changedFileCount == 1)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func invalidLocationsAndExhaustedLimitsAreUnavailable() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        #expect(GitStatusReader().read(at: repo.root) == .unavailable)
        #expect(GitStatusReader().read(at: repo.root.appendingPathComponent("missing")) == .unavailable)
        #expect(GitStatusReader().read(at: URL(string: "https://example.invalid/repo")!) == .unavailable)
        #expect(GitStatusReader(timeout: 0).read(at: repo.directory) == .unavailable)
        #expect(GitStatusReader(timeout: .infinity).read(at: repo.directory) == .unavailable)
        #expect(GitStatusReader(timeout: .greatestFiniteMagnitude).read(at: repo.directory) == .unavailable)
        #expect(GitStatusReader(maximumOutputBytes: 1).read(at: repo.directory) == .unavailable)
    }

    @Test func parserHandlesRawNamesRenameSourceAndDeduplication() throws {
        var bytes = Data("# branch.oid abc\0# branch.head main\0# branch.upstream origin/main\0# branch.ab +2 -3\0".utf8)
        bytes.append(Data("2 RM N... 100644 100644 100644 abc def R100 renamed\n path\0? misleading source\0".utf8))
        bytes.append(Data("1 .M N... 100644 100644 100644 abc def renamed\n path\0".utf8))
        bytes.append(Data("u UU N... 100644 100644 100644 100644 abc def ghi conflict\0? ".utf8))
        bytes.append(0xff)
        bytes.append(Data("\0! ignored\0".utf8))
        let parsed = try #require(GitStatusParser.parse(bytes))
        #expect(parsed.changedFileCount == 3)
        #expect(parsed.conflictedFileCount == 1)
        #expect(parsed.aheadCount == 2)
        #expect(parsed.behindCount == 3)
    }

    @Test func parserRejectsTruncationAndInvalidCounts() {
        let prefix = "# branch.oid abc\0# branch.head main\0"
        for invalid in ["", prefix + "? filename", prefix + "2 R. N... 100644 100644 100644 abc def R100 dest\0",
                        prefix + "# branch.ab +-1 -0\0", prefix + "unknown\0", "? filename\0"] {
            #expect(GitStatusParser.parse(Data(invalid.utf8)) == nil)
        }
    }

    @Test func inheritedGitOverridesAreRemoved() {
        let env = GitStatusReader.environment(["GIT_DIR": "/other", "GIT_WORK_TREE": "/other", "GIT_INDEX_FILE": "/other", "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.fsmonitor", "GIT_CONFIG_VALUE_0": "bad", "HOME": "/home", "PATH": "/unsafe"])
        #expect(env["GIT_DIR"] == nil)
        #expect(env["GIT_INDEX_FILE"] == nil)
        #expect(env["GIT_CONFIG_COUNT"] == nil)
        #expect(env["GIT_CONFIG_VALUE_0"] == nil)
        #expect(env["HOME"] == "/home")
        #expect(env["GIT_OPTIONAL_LOCKS"] == "0")
        #expect(env["GIT_NO_LAZY_FETCH"] == "1")
        #expect(env["GIT_ALLOW_PROTOCOL"] == "")
        #expect(env["PATH"] == "/usr/bin:/bin:/usr/sbin:/sbin")
    }

    @Test func transportGuardBlocksExternalRemoteHelpersEvenIfConfigAllowsThem() throws {
        let repo = try StatusRepository()
        defer { repo.remove() }
        let marker = repo.root.appendingPathComponent("transport-executed")
        let result = try #require(BoundedGitProcess.run(arguments: ["-c", "protocol.ext.allow=always", "ls-remote", "ext::/usr/bin/touch " + marker.path],
                                                      environment: GitStatusReader.environment(ProcessInfo.processInfo.environment),
                                                      deadline: .now.advanced(by: .seconds(2)), maximumOutputBytes: 100))
        #expect(result.exitCode != 0)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func runnerStreamsBothPipesAndEnforcesOutputLimit() throws {
        let input = Data(repeating: 120, count: 300_000)
        let complete = try #require(BoundedGitProcess.run(executable: "/bin/cat", arguments: [], environment: [:], input: input,
                                                        deadline: .now.advanced(by: .seconds(2)), maximumOutputBytes: input.count))
        #expect(complete.exitCode == 0)
        #expect(complete.data == input)
        #expect(BoundedGitProcess.run(executable: "/bin/cat", arguments: [], environment: [:], input: input,
                                     deadline: .now.advanced(by: .seconds(2)), maximumOutputBytes: 10) == nil)
        #expect(BoundedGitProcess.run(executable: "/not/an/executable", arguments: [], environment: [:],
                                     deadline: .now.advanced(by: .seconds(2)), maximumOutputBytes: 10) == nil)
    }

    @Test func runnerStopsAtDeadlineEvenWhenChildKeepsOutputPipeOpen() {
        let start = ContinuousClock.now
        // Synthetic test command; production always executes /usr/bin/git directly.
        let result = BoundedGitProcess.run(executable: "/bin/sh", arguments: ["-c", "/bin/sleep 5 & exit 0"], environment: [:],
                                           deadline: start.advanced(by: .milliseconds(80)), maximumOutputBytes: 100)
        #expect(result == nil)
        #expect(start.duration(to: .now) < .seconds(1))
    }

    @Test func runnerObservesTaskCancellation() async {
        let task = Task.detached {
            BoundedGitProcess.run(executable: "/bin/sleep", arguments: ["5"], environment: [:],
                                  deadline: .now.advanced(by: .seconds(10)), maximumOutputBytes: 100) == nil
        }
        try? await Task.sleep(for: .milliseconds(30))
        let start = ContinuousClock.now
        task.cancel()
        #expect(await task.value)
        #expect(start.duration(to: .now) < .seconds(1))
    }
}

private struct StatusRepository {
    let root: URL
    let directory: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigStatus-" + UUID().uuidString)
        directory = root.appendingPathComponent("repository with spaces")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try git(["init", "-b", "main"])
        try git(["config", "user.name", "Twig Test"])
        try git(["config", "user.email", "twig-test@example.invalid"])
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func write(_ text: String, to path: String) throws {
        let file = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    func commitAll() throws {
        try git(["add", "."])
        try git(["commit", "-m", "Fixture commit"])
    }

    func status() throws -> GitWorktreeStatus {
        let result = GitStatusReader().read(at: directory)
        guard case let .available(status) = result else {
            throw StatusFixtureError.unavailable
        }
        return status
    }

    @discardableResult
    func git(_ arguments: [String], expected: Int32 = 0) throws -> Data {
        var environment = GitStatusReader.environment(ProcessInfo.processInfo.environment)
        // Fixture setup deliberately uses a local file transport for submodule add.
        environment.removeValue(forKey: "GIT_ALLOW_PROTOCOL")
        environment["GIT_CONFIG_SYSTEM"] = "/dev/null"
        environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environment["GIT_AUTHOR_NAME"] = "Twig Test"
        environment["GIT_AUTHOR_EMAIL"] = "twig-test@example.invalid"
        environment["GIT_COMMITTER_NAME"] = "Twig Test"
        environment["GIT_COMMITTER_EMAIL"] = "twig-test@example.invalid"
        guard let result = BoundedGitProcess.run(arguments: ["-C", directory.path] + arguments, environment: environment,
                                                 deadline: .now.advanced(by: .seconds(5)), maximumOutputBytes: 1_048_576),
              result.exitCode == expected else { throw StatusFixtureError.git(arguments) }
        return result.data
    }
}

private enum StatusFixtureError: Error {
    case git([String])
    case unavailable
}
