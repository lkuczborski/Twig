#if TWIG_PREVIEW
import Foundation

/// The review build can use disposable repositories and preferences for captures.
/// This entry point is not compiled into normal or release builds.
enum PreviewEnvironment {
    static var preferencesURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--twig-demo-root"),
              arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            .appendingPathComponent("preferences.json")
    }
}
#endif
