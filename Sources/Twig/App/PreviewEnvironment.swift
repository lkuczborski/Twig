#if TWIG_PREVIEW
import Foundation

/// The review build can use disposable repositories and preferences for captures.
/// This entry point is not compiled into normal or release builds.
enum PreviewEnvironment {
    static func record(_ event: String) {
        guard let url = preferencesURL?.deletingLastPathComponent().appendingPathComponent("preview-events.log") else { return }
        let line = Data("\(event)\n".utf8)
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }

    static var preferencesURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--twig-demo-root"),
              arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            .appendingPathComponent("preferences.json")
    }
}
#endif
