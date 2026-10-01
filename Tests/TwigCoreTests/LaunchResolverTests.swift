import Foundation
import Testing
@testable import TwigCore

@Suite(.serialized)
final class LaunchResolverTests {
    private let folder = URL(fileURLWithPath: "/tmp/twig-resolver-tests/Example", isDirectory: true)

    @Test
    func testHighestConfidenceInstalledCandidateWins() {
        let xcode = candidate(.xcode, target: folder.appendingPathComponent("Example.xcodeproj"), confidence: 98)
        let code = candidate(.vscode, target: folder, confidence: 80)
        let resolution = resolve([code, xcode], installed: [.xcode, .vscode])
        #expect(resolution.destination == .ide(.xcode))
        #expect(resolution.target.lastPathComponent == "Example.xcodeproj")
        #expect(resolution.reason == xcode.reason)
    }

    @Test
    func testUnavailableDetectionTriesNextInstalledCandidate() {
        let resolution = resolve([
            candidate(.xcode, target: folder.appendingPathComponent("Example.xcodeproj"), confidence: 98),
            candidate(.vscode, target: folder, confidence: 60)
        ], installed: [.vscode])
        #expect(resolution.destination == .ide(.vscode))
        #expect(resolution.target.lastPathComponent == folder.lastPathComponent)
    }

    @Test
    func testExplicitMissingOverrideDoesNotSilentlyFallBack() {
        let resolution = resolve([candidate(.xcode, target: folder, confidence: 90)],
                                 installed: [.xcode, .vscode], override: WorktreeOverride(ide: .rider),
                                 fallbackIDE: .vscode)
        #expect(resolution.destination == .missingApp(.rider))
        #expect(resolution.isOverride)
    }

    @Test
    func testDifferentEditorOverrideUsesFolderInsteadOfXcodeProject() {
        let resolution = resolve([
            candidate(.xcode, target: folder.appendingPathComponent("Example.xcodeproj"), confidence: 98)
        ], installed: [.xcode, .vscode], override: WorktreeOverride(ide: .vscode))
        #expect(resolution.destination == .ide(.vscode))
        #expect(resolution.target == folder)
    }

    @Test
    func testOverrideUsesMatchingWorkspaceWhenDetected() {
        let workspace = folder.appendingPathComponent("Example.code-workspace")
        let resolution = resolve([
            candidate(.vscode, target: workspace, confidence: 90),
            candidate(.xcode, target: folder.appendingPathComponent("Example.xcodeproj"), confidence: 98)
        ], installed: [.vscode, .xcode], override: WorktreeOverride(ide: .vscode))
        #expect(resolution.target.lastPathComponent == "Example.code-workspace")
    }

    @Test
    func testFallbackAndFinderWhenNoUsableCandidatesExist() {
        let detection = [candidate(.xcode, target: folder, confidence: 90)]
        let fallback = resolve(detection, installed: [.zed], fallbackIDE: .zed)
        #expect(fallback.destination == .ide(.zed))
        #expect(fallback.target == folder)
        #expect(fallback.candidate == nil)
        let finder = resolve(detection, installed: [], fallbackIDE: .zed)
        #expect(finder.destination == .finder)
        #expect(finder.target == folder)
    }

    @Test
    func testConfiguredFallbackBeatsGenericEditorSuggestion() {
        let generic = ProjectCandidate(ide: .vscode, target: folder, projectKind: "Folder",
                                       reason: "Generic editor", confidence: 10)
        let resolution = resolve([generic], installed: [.vscode, .zed], fallbackIDE: .zed)
        #expect(resolution.destination == .ide(.zed))
        #expect(resolution.candidate == nil)
    }

    @Test
    func testGenericEditorStillOpensWhenNoFallbackIsConfigured() {
        let generic = ProjectCandidate(ide: .vscode, target: folder, projectKind: "Folder",
                                       reason: "Generic editor", confidence: 10)
        let resolution = resolve([generic], installed: [.vscode])
        #expect(resolution.destination == .ide(.vscode))
        #expect(resolution.candidate == generic)
    }

    @Test
    func testSpecificEvidenceBeatsConfiguredFallback() {
        let resolution = resolve([
            candidate(.xcode, target: folder.appendingPathComponent("Example.xcodeproj"), confidence: 95)
        ], installed: [.xcode, .zed], fallbackIDE: .zed)
        #expect(resolution.destination == .ide(.xcode))
    }

    @Test
    func testManualProjectTargetMustStayInsideWorktree() {
        let valid = resolve([], installed: [.xcode],
                            override: WorktreeOverride(ide: .xcode, targetPath: "App/App.xcodeproj"))
        #expect(valid.target.lastPathComponent == "App.xcodeproj")
        let escaped = resolve([], installed: [.xcode],
                              override: WorktreeOverride(ide: .xcode, targetPath: "../Other.xcodeproj"))
        #expect(escaped.target == folder)
        let siblingPrefix = resolve([], installed: [.xcode], override: WorktreeOverride(
            ide: .xcode, targetPath: folder.path + "-other/Other.xcodeproj"))
        #expect(siblingPrefix.target == folder)
    }

    @Test
    func testCandidateTargetsOutsideWorktreeDoNotEscape() {
        let resolution = resolve([candidate(.vscode, target: URL(string: "https://example.com")!, confidence: 99)],
                                 installed: [.vscode])
        #expect(resolution.target == folder)
    }

    @Test
    func testEqualConfidencePreservesDetectorPriority() {
        let resolution = resolve([
            candidate(.cursor, target: folder, confidence: 75),
            candidate(.vscode, target: folder, confidence: 75)
        ], installed: [.cursor, .vscode])
        #expect(resolution.destination == .ide(.cursor))
    }

    private func candidate(_ ide: IDEID, target: URL, confidence: Int) -> ProjectCandidate {
        ProjectCandidate(ide: ide, target: target, projectKind: "Test", reason: "Found \(ide.displayName)",
                         confidence: confidence)
    }

    private func resolve(_ candidates: [ProjectCandidate], installed: Set<IDEID>,
                         override: WorktreeOverride? = nil, fallbackIDE: IDEID? = nil) -> LaunchResolution {
        LaunchResolver.resolve(folder: folder,
                               detection: ProjectDetection(candidates: candidates, scannedFileCount: 1, wasTruncated: false),
                               installed: installed, override: override, fallbackIDE: fallbackIDE)
    }
}
