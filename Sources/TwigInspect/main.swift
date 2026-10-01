import AppKit
import Foundation
import TwigCore

// A read-only smoke-test surface for the same discovery and launch policy as the menu bar app.
// It never launches an IDE, changes preferences, or executes anything from a worktree.
private struct Inspection: Encodable {
    let codexHome: String
    let installedEditors: [String]
    let worktrees: [InspectedWorktree]
    let warnings: [String]
}

private struct InspectedWorktree: Encodable {
    let folder: String
    let repository: String
    let branch: String?
    let headRevision: String?
    let lastActivity: Date
    let selected: InspectedLaunch
    let candidates: [InspectedCandidate]
    let scannedFileCount: Int
    let scanWasTruncated: Bool
}

private struct InspectedLaunch: Encodable {
    let editor: String
    let target: String
    let reason: String
    let isOverride: Bool
    let missingApplication: Bool
}

private struct InspectedCandidate: Encodable {
    let editor: String
    let projectKind: String
    let target: String
    let reason: String
    let confidence: Int
}

private enum InspectionError: LocalizedError {
    case arguments
    var errorDescription: String? { "Usage: TwigInspect [--codex-home PATH]" }
}

@MainActor
private func inspect() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--help"] || arguments == ["-h"] {
        print("Usage: TwigInspect [--codex-home PATH]\nPrint read-only JSON diagnostics; never launch editors or change settings.")
        return
    }
    let explicitHome: String?
    if arguments.isEmpty {
        explicitHome = nil
    } else if arguments.count == 2, arguments[0] == "--codex-home", !arguments[1].isEmpty {
        explicitHome = arguments[1]
    } else {
        throw InspectionError.arguments
    }

    var warnings: [String] = []
    let preferences: TwigPreferences
    do {
        preferences = try FilePreferencesStore().load()
    } catch {
        preferences = TwigPreferences()
        warnings.append(error.localizedDescription)
    }
    let homePath = explicitHome ?? preferences.codexHome ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path
    let home = URL(fileURLWithPath: (homePath as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
    var installed = Set(IDEID.allCases.filter { ide in
        ide.bundleIdentifiers.contains {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
    })
    installed.formUnion(InstalledApplicationScanner().scan(in: InstalledApplicationScanner.standardDirectories).keys)
    let discovery = WorktreeDiscoverer().discover(in: home)
    warnings += discovery.warnings
    let detector = ProjectDetector()
    let rows = discovery.worktrees.map { worktree in
        let detection = detector.detect(at: worktree.folder)
        let resolution = LaunchResolver.resolve(
            folder: worktree.folder, detection: detection, installed: installed,
            override: preferences.overrideForWorktree(worktree.folder), fallbackIDE: preferences.fallbackIDE
        )
        let editor: String
        let missing: Bool
        switch resolution.destination {
        case .finder: editor = "Finder"; missing = false
        case .ide(let ide): editor = ide.displayName; missing = false
        case .missingApp(let ide): editor = ide.displayName; missing = true
        }
        return InspectedWorktree(
            folder: worktree.folder.path, repository: worktree.repositoryName, branch: worktree.branch,
            headRevision: worktree.headRevision, lastActivity: worktree.lastActivity,
            selected: InspectedLaunch(editor: editor, target: resolution.target.path, reason: resolution.reason,
                                      isOverride: resolution.isOverride, missingApplication: missing),
            candidates: detection.candidates.map {
                InspectedCandidate(editor: $0.ide.displayName, projectKind: $0.projectKind,
                                   target: $0.target.path, reason: $0.reason, confidence: $0.confidence)
            },
            scannedFileCount: detection.scannedFileCount, scanWasTruncated: detection.wasTruncated
        )
    }
    let inspection = Inspection(codexHome: home.path, installedEditors: installed.map(\.displayName).sorted(),
                                worktrees: rows, warnings: warnings)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    FileHandle.standardOutput.write(try encoder.encode(inspection))
    FileHandle.standardOutput.write(Data("\n".utf8))
}

do {
    try inspect()
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(2)
}
