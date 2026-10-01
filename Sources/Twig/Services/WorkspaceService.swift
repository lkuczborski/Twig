import AppKit
import TwigCore

/// The only boundary that launches applications. All paths are passed as URLs, never shell commands.
@MainActor
final class WorkspaceService {
    private(set) var applications: [IDEID: URL] = [:]

    func refreshApplications() async {
        applications = Dictionary(uniqueKeysWithValues: IDEID.allCases.compactMap { ide in
            guard let url = ide.bundleIdentifiers.compactMap({
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
            }).first else { return nil }
            return (ide, url)
        })
        let scanned = await Task.detached(priority: .utility) {
            InstalledApplicationScanner().scan(in: InstalledApplicationScanner.standardDirectories)
        }.value
        applications.merge(scanned) { registered, _ in registered }
    }

    func open(_ resolution: LaunchResolution) async throws {
        guard FileManager.default.fileExists(atPath: resolution.target.path) else {
            throw WorkspaceError.missingTarget(resolution.target.path)
        }
        switch resolution.destination {
        case .finder:
            guard NSWorkspace.shared.open(resolution.target) else { throw WorkspaceError.finderFailed }
        case .missingApp(let ide):
            throw WorkspaceError.missingApplication(ide.displayName)
        case .ide(let ide):
            guard let application = applications[ide] else {
                throw WorkspaceError.missingApplication(ide.displayName)
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try await NSWorkspace.shared.open(
                [resolution.target], withApplicationAt: application, configuration: configuration
            )
        }
    }

    func openFolder(_ folder: URL) throws {
        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw WorkspaceError.missingTarget(folder.path)
        }
        guard NSWorkspace.shared.open(folder) else { throw WorkspaceError.finderFailed }
    }

    func reveal(_ folder: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    func copyPath(_ folder: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(folder.path, forType: .string)
    }
}

enum WorkspaceError: LocalizedError {
    case missingTarget(String), missingApplication(String), finderFailed
    var errorDescription: String? {
        switch self {
        case .missingTarget(let path): "This worktree or project no longer exists: \(path). Refresh the list."
        case .missingApplication(let name): "\(name) is not installed. Choose another editor or restore Automatic for this worktree."
        case .finderFailed: "Finder could not open this folder."
        }
    }
}
