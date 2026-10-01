import Foundation

/// Reads Git's own worktree metadata without running Git, a shell, or project code.
///
/// The supported Codex layout is `worktrees/<identifier>/<repository>`. Discovery
/// also accepts a checkout directly at `worktrees/<identifier>`. Symlinked
/// checkouts and symlinked children are never traversed. Codex conversations,
/// session logs, credentials, and Git commit messages are never read.
public struct WorktreeDiscoverer: Sendable {
    public init() {}

    public func discover(in codexHome: URL) -> WorktreeDiscoveryResult {
        let manager = FileManager.default
        let root = codexHome.appendingPathComponent("worktrees", isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        var warnings: [String] = []
        var discovered: [String: Worktree] = [:]

        guard manager.fileExists(atPath: root.path) else {
            return WorktreeDiscoveryResult(worktrees: [], warnings: [])
        }

        do {
            for bucket in try children(of: root) where isDirectoryWithoutSymlink(bucket) {
                if Task.isCancelled { break }
                let candidates: [URL]
                if manager.fileExists(atPath: bucket.appendingPathComponent(".git").path) {
                    candidates = [bucket]
                } else {
                    do {
                        candidates = try children(of: bucket).filter(isDirectoryWithoutSymlink)
                    } catch {
                        warnings.append("Could not read worktree group ‘\(bucket.lastPathComponent)’: \(error.localizedDescription)")
                        continue
                    }
                }

                for candidate in candidates {
                    if Task.isCancelled { break }
                    let dotGit = candidate.appendingPathComponent(".git")
                    guard manager.fileExists(atPath: dotGit.path) else { continue }
                    do {
                        let worktree = try inspect(candidate)
                        discovered[worktree.id] = worktree
                    } catch {
                        warnings.append("Skipped ‘\(candidate.lastPathComponent)’ (\(bucket.lastPathComponent)): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            warnings.append("Could not read Codex worktrees: \(error.localizedDescription)")
        }

        return WorktreeDiscoveryResult(
            worktrees: discovered.values.sorted {
                $0.lastActivity == $1.lastActivity ? $0.id < $1.id : $0.lastActivity > $1.lastActivity
            },
            warnings: warnings
        )
    }

    private func inspect(_ folder: URL) throws -> Worktree {
        let dotGit = folder.appendingPathComponent(".git")
        let attributes = try dotGit.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard attributes.isSymbolicLink != true else { throw MetadataError.invalid("The .git entry is a symbolic link.") }

        let gitDirectory: URL
        if attributes.isDirectory == true {
            gitDirectory = dotGit
        } else {
            let pointer = try readSmallText(dotGit)
            guard pointer.hasPrefix("gitdir: ") else { throw MetadataError.invalid("The .git pointer is invalid.") }
            let path = String(pointer.dropFirst("gitdir: ".count))
            guard !path.isEmpty, !path.contains("\n"), !path.contains("\r"), !path.contains("\0") else {
                throw MetadataError.invalid("The .git pointer is invalid.")
            }
            gitDirectory = resolve(path, relativeTo: folder).resolvingSymlinksInPath()
            guard isDirectoryWithoutSymlink(gitDirectory) else {
                throw MetadataError.invalid("The Git worktree metadata is missing.")
            }

            // Git writes a reciprocal pointer. If present, reject stale copies that
            // now belong to another checkout. Older/nonstandard metadata may omit it.
            let backlink = gitDirectory.appendingPathComponent("gitdir")
            if FileManager.default.fileExists(atPath: backlink.path) {
                let value = try readSmallText(backlink)
                let expected = dotGit.standardizedFileURL.resolvingSymlinksInPath()
                guard !value.isEmpty,
                      resolve(value, relativeTo: gitDirectory).resolvingSymlinksInPath() == expected else {
                    throw MetadataError.invalid("The Git metadata belongs to a different checkout.")
                }
            }
        }

        let headURL = gitDirectory.appendingPathComponent("HEAD")
        let head = try readSmallText(headURL)
        let commonDirectory = try commonGitDirectory(for: gitDirectory)
        let branch: String?
        let revision: String?
        var activityFiles = [dotGit, headURL]

        if head.hasPrefix("ref: ") {
            let reference = String(head.dropFirst("ref: ".count))
            guard isSafeReference(reference) else { throw MetadataError.invalid("The Git HEAD reference is invalid.") }
            branch = reference.hasPrefix("refs/heads/") ? String(reference.dropFirst("refs/heads/".count)) : nil
            revision = try resolveReference(reference, gitDirectory: gitDirectory, commonDirectory: commonDirectory)
            activityFiles += [gitDirectory.appendingPathComponent(reference), commonDirectory.appendingPathComponent(reference)]
        } else {
            guard isObjectID(head) else { throw MetadataError.invalid("The Git HEAD is invalid.") }
            branch = nil
            revision = head.lowercased()
        }

        activityFiles += ["index", "logs/HEAD", "codex-thread.json"].map { gitDirectory.appendingPathComponent($0) }
        let lastActivity = (activityFiles.compactMap(modificationDate) + [projectActivity(in: folder)]).max() ?? .distantPast
        let canonicalFolder = folder.standardizedFileURL.resolvingSymlinksInPath()
        return Worktree(
            id: canonicalFolder.path,
            folder: canonicalFolder,
            repositoryName: canonicalFolder.lastPathComponent,
            branch: branch,
            headRevision: revision,
            lastActivity: lastActivity
        )
    }

    private func commonGitDirectory(for gitDirectory: URL) throws -> URL {
        let pointer = gitDirectory.appendingPathComponent("commondir")
        guard FileManager.default.fileExists(atPath: pointer.path) else { return gitDirectory }
        let path = try readSmallText(pointer)
        guard !path.isEmpty, !path.contains("\n"), !path.contains("\r"), !path.contains("\0") else {
            throw MetadataError.invalid("The common Git directory pointer is invalid.")
        }
        let resolved = resolve(path, relativeTo: gitDirectory).resolvingSymlinksInPath()
        guard isDirectoryWithoutSymlink(resolved) else {
            throw MetadataError.invalid("The common Git directory is missing.")
        }
        return resolved
    }

    private func resolveReference(
        _ reference: String,
        gitDirectory: URL,
        commonDirectory: URL,
        visited: Set<String> = []
    ) throws -> String? {
        guard isSafeReference(reference), !visited.contains(reference), visited.count < 8 else {
            throw MetadataError.invalid("Git references contain an invalid path or cycle.")
        }
        let visited = visited.union([reference])
        for directory in [gitDirectory, commonDirectory] {
            let refFile = directory.appendingPathComponent(reference)
            guard FileManager.default.fileExists(atPath: refFile.path) else { continue }
            guard refFile.standardizedFileURL == refFile.resolvingSymlinksInPath() else {
                throw MetadataError.invalid("A Git reference crosses a symbolic link.")
            }
            let text = try readSmallText(refFile)
            if text.hasPrefix("ref: ") {
                return try resolveReference(String(text.dropFirst(5)), gitDirectory: gitDirectory,
                                            commonDirectory: commonDirectory, visited: visited)
            }
            guard isObjectID(text) else { throw MetadataError.invalid("A Git reference contains an invalid revision.") }
            return text.lowercased()
        }

        let packedRefs = commonDirectory.appendingPathComponent("packed-refs")
        if FileManager.default.fileExists(atPath: packedRefs.path) {
            let text = try readSmallText(packedRefs, maximumBytes: 8 * 1_024 * 1_024)
            for line in text.split(whereSeparator: \.isNewline) {
                guard !line.hasPrefix("#"), !line.hasPrefix("^") else { continue }
                let parts = line.split(separator: " ", maxSplits: 1)
                if parts.count == 2, parts[1] == reference, isObjectID(String(parts[0])) {
                    return String(parts[0]).lowercased()
                }
            }
        }
        // An unborn branch legitimately has a HEAD ref but no commit yet.
        return nil
    }

    private func isSafeReference(_ reference: String) -> Bool {
        guard reference.hasPrefix("refs/"), !reference.hasSuffix("."), !reference.contains(".."),
              !reference.contains("@{"), !reference.unicodeScalars.contains(where: {
                  $0.value < 33 || $0.value == 127 || "~^:?*[\\".unicodeScalars.contains($0)
              }) else { return false }
        return reference.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && !$0.hasPrefix(".") && !$0.hasSuffix(".lock")
        }
    }

    private func isObjectID(_ value: String) -> Bool {
        (value.utf8.count == 40 || value.utf8.count == 64) && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }

    private func readSmallText(_ url: URL, maximumBytes: Int = 16_384) throws -> String {
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
              (attributes.fileSize ?? maximumBytes + 1) <= maximumBytes else {
            throw MetadataError.invalid("Git metadata is not a regular file or exceeds the size limit.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes, let text = String(data: data, encoding: .utf8) else {
            throw MetadataError.invalid("Git metadata is too large or not UTF-8.")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolve(_ path: String, relativeTo directory: URL) -> URL {
        (path.hasPrefix("/") ? URL(fileURLWithPath: path) : directory.appendingPathComponent(path)).standardizedFileURL
    }

    private func children(of directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func isDirectoryWithoutSymlink(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func modificationDate(_ url: URL) -> Date? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isSymbolicLinkKey]),
              values.isSymbolicLink != true else { return nil }
        return values.contentModificationDate
    }

    /// A bounded metadata-only scan catches source edits without crawling dependencies.
    /// Three directory levels and at most 2,000 entries are examined per checkout.
    /// Deeper edits become visible when Git's index or HEAD log changes.
    private func projectActivity(in folder: URL) -> Date {
        let excluded: Set<String> = [
            ".git", ".build", ".swiftpm", ".next", ".nuxt", ".turbo", ".gradle", ".venv",
            "node_modules", "vendor", "Pods", "Carthage", "DerivedData", "build", "dist", "target", "coverage", "venv"
        ]
        var newest = modificationDate(folder) ?? .distantPast
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let entries = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return newest }
        var examined = 0
        for case let entry as URL in entries {
            guard examined < 2_000, !Task.isCancelled else { break }
            examined += 1
            guard !excluded.contains(entry.lastPathComponent),
                  let values = try? entry.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true else {
                entries.skipDescendants()
                continue
            }
            if let date = values.contentModificationDate { newest = max(newest, date) }
            if values.isDirectory == true && entries.level >= 3 { entries.skipDescendants() }
        }
        return newest
    }
}

private enum MetadataError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self { case .invalid(let reason): reason }
    }
}
