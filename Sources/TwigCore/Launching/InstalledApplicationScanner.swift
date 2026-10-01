import Foundation

/// Complements Launch Services for unregistered apps and installations in vendor subfolders.
/// Scans only explicitly supplied application directories and never starts an app or executable.
public struct InstalledApplicationScanner: Sendable {
    public init() {}

    public static var standardDirectories: [URL] {
        [URL(fileURLWithPath: "/Applications", isDirectory: true),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
    }

    /// At most three directory levels and 6,000 entries are examined across the supplied roots.
    /// First matching installation wins, so callers can put preferred roots first.
    public func scan(in directories: [URL]) -> [IDEID: URL] {
        let identifiers = Dictionary(uniqueKeysWithValues: IDEID.allCases.flatMap { ide in
            ide.bundleIdentifiers.map { ($0.lowercased(), ide) }
        })
        var result: [IDEID: URL] = [:]
        var visited = 0
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]

        for root in directories {
            guard root.isFileURL, isDirectoryWithoutSymlink(root) else { continue }
            var queue: [(URL, Int)] = [(root.standardizedFileURL, 0)]
            var index = 0
            while index < queue.count && visited < 6_000 {
                let (directory, depth) = queue[index]
                index += 1
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
                ).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else { continue }
                for entry in entries {
                    guard visited < 6_000 else { break }
                    visited += 1
                    guard isDirectoryWithoutSymlink(entry) else { continue }
                    if entry.pathExtension.lowercased() == "app" {
                        if let identifier = bundleIdentifier(in: entry), let ide = identifiers[identifier.lowercased()],
                           result[ide] == nil {
                            result[ide] = entry.standardizedFileURL.resolvingSymlinksInPath()
                        }
                        // Never descend into app bundles, including their embedded helper apps.
                    } else if depth + 1 < 3 {
                        queue.append((entry, depth + 1))
                    }
                }
            }
        }
        return result
    }

    private func isDirectoryWithoutSymlink(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func bundleIdentifier(in app: URL) -> String? {
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        guard isDirectoryWithoutSymlink(contents) else { return nil }
        let info = contents.appendingPathComponent("Info.plist")
        let limit = 262_144
        guard let values = try? info.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= limit,
              let handle = try? FileHandle(forReadingFrom: info) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: limit + 1), data.count <= limit,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any] else { return nil }
        return dictionary["CFBundleIdentifier"] as? String
    }
}
