import Foundation
import Testing
@testable import TwigCore

@Suite(.serialized)
final class InstalledApplicationScannerTests {
    @Test
    func readsKnownBundleIdentifiersInVendorFolders() throws {
        try withDirectory { root in
            let xcode = try makeApp("Xcode.app", identifier: "com.apple.dt.Xcode", in: root)
            let pycharm = try makeApp("JetBrains/2026/PyCharm.app", identifier: "com.jetbrains.pycharm.ce", in: root)
            _ = try makeApp("Unrelated.app", identifier: "example.unrelated", in: root)
            let installed = InstalledApplicationScanner().scan(in: [root])
            #expect(installed[.xcode] == xcode)
            #expect(installed[.pycharm] == pycharm)
            #expect(installed.count == 2)
        }
    }

    @Test
    func skipsSymlinksEmbeddedAppsAndDeeperFolders() throws {
        try withDirectory { root in
            let outside = root.appendingPathComponent("outside", isDirectory: true)
            let scanned = root.appendingPathComponent("Applications", isDirectory: true)
            try FileManager.default.createDirectory(at: scanned, withIntermediateDirectories: true)
            let real = try makeApp("Xcode.app", identifier: "com.apple.dt.Xcode", in: outside)
            try FileManager.default.createSymbolicLink(at: scanned.appendingPathComponent("Alias.app"), withDestinationURL: real)
            _ = try makeApp("One/Two/Three/Code.app", identifier: "com.microsoft.VSCode", in: scanned)
            _ = try makeApp("Container.app/Contents/Helper.app", identifier: "com.jetbrains.WebStorm", in: scanned)
            #expect(InstalledApplicationScanner().scan(in: [scanned]).isEmpty)
        }
    }

    @Test
    func ignoresInvalidPlistsAndPrefersFirstSuppliedDirectory() throws {
        try withDirectory { root in
            let primary = root.appendingPathComponent("primary")
            let secondary = root.appendingPathComponent("secondary")
            let first = try makeApp("Code.app", identifier: "com.microsoft.VSCode", in: primary)
            _ = try makeApp("Code Insiders.app", identifier: "com.microsoft.VSCodeInsiders", in: secondary)
            let malformed = try makeApp("Broken.app", identifier: "com.apple.dt.Xcode", in: primary)
            try Data("not a plist".utf8).write(to: malformed.appendingPathComponent("Contents/Info.plist"))
            let installed = InstalledApplicationScanner().scan(in: [primary, secondary])
            #expect(installed[.vscode] == first)
            #expect(installed[.xcode] == nil)
        }
    }

    private func makeApp(_ path: String, identifier: String, in root: URL) throws -> URL {
        let app = root.appendingPathComponent(path, isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": identifier],
                                                       format: .binary, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        // macOS enumerates /var-backed temporary fixtures using their /private/var path.
        return app.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigAppScanner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
