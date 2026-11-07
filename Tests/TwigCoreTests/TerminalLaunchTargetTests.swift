import Foundation
import Testing
@testable import TwigCore

@Suite
struct TerminalLaunchTargetTests {
    @Test func specialPathCharactersRemainOneDirectoryURL() throws {
        try withFixture { root in
            let name = "space ' quote \" dollar $(touch nope); & \\ unicode café\nline"
            let folder = root.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = try TerminalLaunchTarget(folder: folder)
            #expect(target.directory.isFileURL)
            #expect(target.directory.lastPathComponent == name)
            #expect(target.directory.path == folder.resolvingSymlinksInPath().path)
        }
    }

    @Test func relativeComponentsAndSymlinksResolveToDirectory() throws {
        try withFixture { root in
            let folder = root.appendingPathComponent("App", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let alias = root.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)
            let target = try TerminalLaunchTarget(folder: alias.appendingPathComponent("../alias"))
            #expect(target.directory.path == folder.resolvingSymlinksInPath().path)
        }
    }

    @Test func refusesRemoteURLsFilesAndRemovedFolders() throws {
        try withFixture { root in
            #expect(throws: TerminalLaunchError.invalidDirectory) {
                try TerminalLaunchTarget(folder: URL(string: "https://example.com/App")!)
            }
            #expect(throws: TerminalLaunchError.invalidDirectory) {
                try TerminalLaunchTarget(folder: root.appendingPathComponent("missing"))
            }
            let file = root.appendingPathComponent("script.command")
            try Data("echo never execute".utf8).write(to: file)
            #expect(throws: TerminalLaunchError.invalidDirectory) { try TerminalLaunchTarget(folder: file) }
        }
    }

    private func withFixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigTerminalTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
