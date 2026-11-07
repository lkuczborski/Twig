import Foundation
import Testing
@testable import TwigCore

@Suite
struct OpeningActionsTests {
    private let folder = URL(fileURLWithPath: "/tmp/twig-opening-tests/App", isDirectory: true)

    @Test func worktreeChoiceWinsOverRepositoryChoice() {
        let resolution = LaunchResolver.resolve(
            folder: folder, detection: detection(), installed: [.xcode, .vscode, .zed],
            override: WorktreeOverride(ide: .zed), repositoryIDE: .vscode, fallbackIDE: .xcode
        )
        #expect(resolution.destination == .ide(.zed))
        #expect(resolution.target == folder)
        #expect(resolution.reason == "Your editor choice for this worktree")
    }

    @Test func repositoryChoiceWinsOverDetectionAndUsesMatchingNestedTarget() {
        let resolution = LaunchResolver.resolve(folder: folder, detection: detection(),
                                                installed: [.xcode, .vscode], repositoryIDE: .vscode)
        #expect(resolution.destination == .ide(.vscode))
        #expect(resolution.target.path.hasSuffix("web/App.code-workspace"))
        #expect(resolution.reason == "Your editor choice for this repository")
    }

    @Test func repositoryChoiceWithoutCandidateUsesCurrentCheckoutFolder() {
        let resolution = LaunchResolver.resolve(folder: folder, detection: detection(),
                                                installed: [.xcode, .zed], repositoryIDE: .zed)
        #expect(resolution.destination == .ide(.zed))
        #expect(resolution.target == folder)
    }

    @Test func missingRepositoryEditorDoesNotSilentlyFallBack() {
        let resolution = LaunchResolver.resolve(folder: folder, detection: detection(),
                                                installed: [.xcode], repositoryIDE: .vscode,
                                                fallbackIDE: .xcode)
        #expect(resolution.destination == .missingApp(.vscode))
        #expect(resolution.isOverride)
    }

    @Test func repositoryTargetCannotEscapeCurrentCheckout() {
        let escaped = ProjectDetection(candidates: [
            ProjectCandidate(ide: .xcode, target: folder.appendingPathComponent("../Other/Other.xcodeproj"),
                             projectKind: "Xcode", reason: "Fixture", confidence: 99)
        ], scannedFileCount: 1, wasTruncated: false)
        let resolution = LaunchResolver.resolve(folder: folder, detection: escaped,
                                                installed: [.xcode], repositoryIDE: .xcode)
        #expect(resolution.target == folder)
    }

    @Test func oneTimeChoiceUsesItsOwnTargetWithoutChangingSavedDefault() {
        var preferences = TwigPreferences()
        let worktree = makeWorktree(folder, common: folder.appendingPathComponent(".git"))
        preferences.setOverride(WorktreeOverride(ide: .xcode, targetPath: "ios/App.xcodeproj"), for: folder)
        preferences.setEditor(.zed, forRepository: worktree)
        let once = LaunchResolver.resolveOnce(folder: folder, detection: detection(),
                                             installed: [.xcode, .vscode, .zed], ide: .vscode)
        #expect(once.destination == .ide(.vscode))
        #expect(once.target.path.hasSuffix("web/App.code-workspace"))
        #expect(!once.isOverride)
        let next = LaunchResolver.resolve(folder: folder, detection: detection(),
                                         installed: [.xcode, .vscode, .zed],
                                         override: preferences.overrideForWorktree(folder),
                                         repositoryIDE: preferences.editorForRepository(worktree))
        #expect(next.destination == .ide(.xcode))
        #expect(next.target.path.hasSuffix("ios/App.xcodeproj"))
    }

    @Test func repositoryPreferencesApplyToSiblingsButNotSameNamedRepositories() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TwigRepositoryTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let common = root.appendingPathComponent("repository/.git")
        try FileManager.default.createDirectory(at: common, withIntermediateDirectories: true)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: common)
        let first = makeWorktree(root.appendingPathComponent("first/App"), common: common)
        let sibling = makeWorktree(root.appendingPathComponent("second/App"), common: alias)
        let unrelated = makeWorktree(root.appendingPathComponent("third/App"), common: root.appendingPathComponent("other/.git"))
        var preferences = TwigPreferences()
        preferences.setEditor(.vscode, forRepository: first)
        #expect(preferences.editorForRepository(sibling) == .vscode)
        #expect(preferences.editorForRepository(unrelated) == nil)
        let reloaded = try JSONDecoder().decode(TwigPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(reloaded == preferences)
        preferences.setEditor(nil, forRepository: sibling)
        #expect(preferences.repositoryEditors.isEmpty)
    }

    @Test func legacyPreferencesDecodeWithoutRepositoryDefaults() throws {
        let data = Data(#"{"schemaVersion":1,"fallbackIDE":"xcode","overrides":{},"lastOpened":{}}"#.utf8)
        let preferences = try JSONDecoder().decode(TwigPreferences.self, from: data)
        #expect(preferences.fallbackIDE == .xcode)
        #expect(preferences.repositoryEditors.isEmpty)
    }

    private func detection() -> ProjectDetection {
        ProjectDetection(candidates: [
            ProjectCandidate(ide: .xcode, target: folder.appendingPathComponent("ios/App.xcodeproj"),
                             projectKind: "Xcode", reason: "Fixture", confidence: 99),
            ProjectCandidate(ide: .vscode, target: folder.appendingPathComponent("web/App.code-workspace"),
                             projectKind: "VS Code workspace", reason: "Fixture", confidence: 90)
        ], scannedFileCount: 2, wasTruncated: false)
    }

    private func makeWorktree(_ folder: URL, common: URL) -> Worktree {
        Worktree(id: folder.path, folder: folder, repositoryName: "App", branch: "main", headRevision: nil,
                 lastActivity: .distantPast, gitDirectory: common, commonGitDirectory: common)
    }
}
