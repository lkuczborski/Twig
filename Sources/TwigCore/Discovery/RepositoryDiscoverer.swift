import Foundation

public struct RepositoryRootStatus: Identifiable, Sendable, Equatable {
    public var id: String { root.path }
    public let root: URL
    public let commonGitDirectory: URL?
    public let isAvailable: Bool
    public let worktreeCount: Int
    public let message: String?
}

public struct RepositoryDiscoveryResult: Sendable {
    public let worktrees: [Worktree]
    public let warnings: [String]
    public let status: RepositoryRootStatus
}

/// Follows Git's registered checkout pointers; never runs Git or repository code.
public struct RepositoryDiscoverer: Sendable {
    public init() {}

    public func discover(at selectedRoot: URL) -> RepositoryDiscoveryResult {
        let root = selectedRoot.standardizedFileURL.resolvingSymlinksInPath()
        let inspector = WorktreeDiscoverer()
        var found: [String: Worktree] = [:]
        var warnings: [String] = []
        do {
            guard isDirectory(root) else { throw RepositoryError.invalid("Folder unavailable. Reconnect its drive or choose another repository.") }
            let common: URL
            if FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path) {
                let selected = try inspector.inspect(root)
                guard let directory = selected.commonGitDirectory else { throw RepositoryError.invalid("Git metadata is unavailable.") }
                common = directory.standardizedFileURL.resolvingSymlinksInPath()
                found[selected.id] = selected
            } else if isDirectory(root.appendingPathComponent("objects")), isDirectory(root.appendingPathComponent("refs")) {
                // A bare repository has no main checkout, but can own linked worktrees.
                let head = try readPointer(root.appendingPathComponent("HEAD"))
                guard head.hasPrefix("ref: refs/") || ([40, 64].contains(head.utf8.count) && head.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })) else {
                    throw RepositoryError.invalid("The repository HEAD is invalid.")
                }
                common = root
            } else {
                throw RepositoryError.invalid("Choose a Git checkout or a bare repository.")
            }

            let repositoryName = common.lastPathComponent == ".git"
                ? common.deletingLastPathComponent().lastPathComponent
                : (common.lastPathComponent.hasSuffix(".git") ? String(common.lastPathComponent.dropLast(4)) : root.lastPathComponent)

            if common.lastPathComponent == ".git" {
                let mainFolder = common.deletingLastPathComponent()
                do {
                    let main = try inspector.inspect(mainFolder)
                    if main.gitDirectory?.standardizedFileURL.resolvingSymlinksInPath() == common {
                        found[main.id] = main
                    }
                } catch {
                    warnings.append("Could not read the main checkout for ‘\(repositoryName)’: \(error.localizedDescription)")
                }
            }

            let registrations = common.appendingPathComponent("worktrees", isDirectory: true)
            if FileManager.default.fileExists(atPath: registrations.path) {
                guard isDirectory(registrations) else { throw RepositoryError.invalid("Git's worktree registry is unavailable.") }
                let entries = try FileManager.default.contentsOfDirectory(at: registrations, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                for admin in entries where isDirectory(admin) {
                    if Task.isCancelled { break }
                    do {
                        let pointer = try readPointer(admin.appendingPathComponent("gitdir"))
                        let dotGit = resolve(pointer, relativeTo: admin).resolvingSymlinksInPath()
                        guard dotGit.lastPathComponent == ".git" else { throw RepositoryError.invalid("The checkout pointer is invalid.") }
                        let folder = dotGit.deletingLastPathComponent()
                        guard isDirectory(folder) else { throw RepositoryError.invalid("The checkout folder is unavailable.") }
                        let worktree = try inspector.inspect(folder)
                        guard worktree.gitDirectory?.standardizedFileURL.resolvingSymlinksInPath() == admin.standardizedFileURL.resolvingSymlinksInPath(),
                              worktree.commonGitDirectory?.standardizedFileURL.resolvingSymlinksInPath() == common else {
                            throw RepositoryError.invalid("The registration belongs to a different checkout.")
                        }
                        found[worktree.id] = worktree
                    } catch {
                        warnings.append("Skipped ‘\(admin.lastPathComponent)’ in ‘\(repositoryName)’: \(error.localizedDescription)")
                    }
                }
            }
            let worktrees = found.values.map {
                Worktree(id: $0.id, folder: $0.folder, repositoryName: repositoryName, branch: $0.branch,
                         headRevision: $0.headRevision, lastActivity: $0.lastActivity,
                         gitDirectory: $0.gitDirectory, commonGitDirectory: $0.commonGitDirectory)
            }.sorted { $0.lastActivity == $1.lastActivity ? $0.id < $1.id : $0.lastActivity > $1.lastActivity }
            return RepositoryDiscoveryResult(worktrees: worktrees, warnings: warnings,
                status: RepositoryRootStatus(root: root, commonGitDirectory: common, isAvailable: true,
                                             worktreeCount: worktrees.count, message: nil))
        } catch {
            let message = error.localizedDescription
            return RepositoryDiscoveryResult(worktrees: [], warnings: ["‘\(root.lastPathComponent)’: \(message)"],
                status: RepositoryRootStatus(root: root, commonGitDirectory: nil, isAvailable: false,
                                             worktreeCount: 0, message: message))
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func readPointer(_ url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 16_385) <= 16_384 else {
            throw RepositoryError.invalid("Git metadata is not a small regular file.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16_385) ?? Data()
        guard data.count <= 16_384, let text = String(data: data, encoding: .utf8) else {
            throw RepositoryError.invalid("Git metadata is too large or not UTF-8.")
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("\n"), !value.contains("\r"), !value.contains("\0") else {
            throw RepositoryError.invalid("The Git metadata pointer is invalid.")
        }
        return value
    }

    private func resolve(_ path: String, relativeTo folder: URL) -> URL {
        (path.hasPrefix("/") ? URL(fileURLWithPath: path) : folder.appendingPathComponent(path)).standardizedFileURL
    }
}

private enum RepositoryError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let reason): reason } }
}
