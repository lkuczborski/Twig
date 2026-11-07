import Foundation
import Testing
@testable import TwigCore

struct WorktreePresentationTests {
    private let folder = URL(fileURLWithPath: "/tmp/TwigPresentation/Project", isDirectory: true)

    @Test func explicitTargetDoesNotInheritAnUnrelatedCandidateType() {
        let old = candidate("Swift package", target: folder.appendingPathComponent("Package.swift"))
        let target = folder.appendingPathComponent("Web/app.code-workspace")
        let resolution = resolution(target: target, candidate: old)
        #expect(WorktreePresentation.projectType(detection: detection([old]), resolution: resolution) == nil)
    }

    @Test func explicitTargetFindsItsOwnDetectedType() {
        let old = candidate("Xcode project", target: folder.appendingPathComponent("Old.xcodeproj"))
        let selected = candidate("Xcode workspace", target: folder.appendingPathComponent("New.xcworkspace"))
        #expect(WorktreePresentation.projectType(detection: detection([old, selected]),
                                                resolution: resolution(target: selected.target, candidate: old)) == "Xcode workspace")
    }

    @Test func selectedTargetKeepsItsTypeEvenWhenAnotherTargetRanksHigher() {
        let sibling = candidate("Python", target: folder.appendingPathComponent("Server"), confidence: 99)
        let selected = candidate("Rust", target: folder.appendingPathComponent("CLI"), confidence: 65)
        #expect(WorktreePresentation.projectType(detection: detection([sibling, selected]),
                                                resolution: resolution(target: selected.target, candidate: selected)) == "Rust")
    }

    @Test func editorFolderMetadataCanRevealManifestAtTheSameTarget() {
        let editor = candidate("VS Code folder", target: folder, confidence: 97)
        let language = candidate("JavaScript / TypeScript", target: folder, confidence: 74)
        #expect(WorktreePresentation.projectType(detection: detection([editor, language]),
                                                resolution: resolution(target: folder, candidate: editor)) == "JS / TS")
    }

    @Test func genericAndEditorOnlyDescriptionsAreOmitted() {
        for kind in ["Folder", "Cursor folder", "PyCharm project", "JetBrains project"] {
            let editor = candidate(kind, target: folder, confidence: kind == "Folder" ? 10 : 97)
            #expect(WorktreePresentation.projectType(detection: detection([editor]),
                                                    resolution: resolution(target: folder, candidate: editor)) == nil)
        }
    }

    @Test func folderFallbackDoesNotBorrowANestedProjectsType() {
        let nested = candidate("Python", target: folder.appendingPathComponent("Services/API"))
        #expect(WorktreePresentation.projectType(detection: detection([nested]),
                                                resolution: resolution(target: folder)) == nil)
    }

    @Test func dottedFolderNameDoesNotTurnEditorMetadataIntoAProjectFormat() {
        let dottedFolder = folder.appendingPathComponent("My.Project", isDirectory: true)
        let editor = candidate("PyCharm project", target: dottedFolder, confidence: 97)
        #expect(WorktreePresentation.projectType(detection: detection([editor]),
                                                resolution: resolution(target: dottedFolder, candidate: editor)) == nil)
    }

    @Test func equivalentStandardizedTargetPathsMatch() {
        let selected = candidate("Go", target: folder.appendingPathComponent("Sources/../CLI"))
        #expect(WorktreePresentation.projectType(detection: detection([selected]),
                                                resolution: resolution(target: folder.appendingPathComponent("CLI"))) == "Go")
    }

    @Test func neverOpenedHasNoInventedRecency() {
        #expect(WorktreePresentation.lastOpenedLabel(nil) == nil)
    }

    @Test func openAgeUsesBoundedUnitsAndDoesNotClaimFutureActivity() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(120), now: now) == "Opened just now")
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(-59), now: now) == "Opened just now")
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(-720), now: now) == "Opened 12m ago")
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(-7_200), now: now) == "Opened 2h ago")
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(-172_800), now: now) == "Opened 2d ago")
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(-1_209_600), now: now) == "Opened 2w ago")
        #expect(WorktreePresentation.lastOpenedLabel(now.addingTimeInterval(-63_072_000), now: now) == "Opened 2y ago")
    }

    private func candidate(_ kind: String, target: URL, confidence: Int = 85) -> ProjectCandidate {
        ProjectCandidate(ide: .vscode, target: target, projectKind: kind, reason: "Fixture", confidence: confidence)
    }

    private func detection(_ candidates: [ProjectCandidate]) -> ProjectDetection {
        ProjectDetection(candidates: candidates, scannedFileCount: 0, wasTruncated: false)
    }

    private func resolution(target: URL, candidate: ProjectCandidate? = nil) -> LaunchResolution {
        LaunchResolution(destination: .ide(.vscode), target: target, reason: "Fixture", candidate: candidate)
    }
}
