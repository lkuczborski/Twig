import Foundation

/// Terminal receives one directory URL through Launch Services. No path becomes shell code.
public struct TerminalLaunchTarget: Equatable, Sendable {
    public static let bundleIdentifier = "com.apple.Terminal"
    public let directory: URL

    public init(folder: URL) throws {
        guard folder.isFileURL else { throw TerminalLaunchError.invalidDirectory }
        let normalized = folder.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw TerminalLaunchError.invalidDirectory
        }
        directory = normalized
    }
}

public enum TerminalLaunchError: LocalizedError, Equatable {
    case invalidDirectory

    public var errorDescription: String? {
        "This worktree folder is unavailable. Refresh the list and try again."
    }
}
