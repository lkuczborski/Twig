import Foundation
import Testing
@testable import TwigCore

@Suite(.serialized)
struct ProjectDetectorTests {
    @Test func testWorkspaceWinsOverSiblingXcodeProjectAndInternalWorkspaceIsNotScanned() throws {
        let fixture = try DetectionFixture()
        try fixture.directory("My App.xcworkspace")
        try fixture.directory("My App.xcodeproj/project.xcworkspace")

        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .xcode)
        #expect(result.candidates.first?.target.lastPathComponent == "My App.xcworkspace")
        #expect(result.candidates.filter { $0.ide == .xcode }.count == 2)
        #expect(!(result.candidates.contains { $0.target.path.contains("xcodeproj/project.xcworkspace") }))
    }

    @Test func testExplicitEditorEvidenceBeatsLanguageHeuristics() throws {
        let fixture = try DetectionFixture()
        try fixture.file("pyproject.toml", "[project]\nname = 'example'")
        try fixture.file(".vscode/settings.json", "{}")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .vscode)
        #expect(result.candidates.first?.target == fixture.root)
        #expect(result.candidates.contains { $0.ide == .pycharm && $0.projectKind == "Python" })
        #expect(result.candidates.first?.reason.contains(".vscode") == true)
    }

    @Test func testVSCodeWorkspaceWithSpacesIsOpenedAsDocument() throws {
        let fixture = try DetectionFixture()
        try fixture.file("My Work Tree.code-workspace", "{\"folders\":[{\"path\":\".\"}]}")
        try fixture.file("package.json", "{}")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .vscode)
        #expect(result.candidates.first?.target == fixture.root.appendingPathComponent("My Work Tree.code-workspace"))
    }

    @Test func testNestedMonorepoProjectsKeepTheirOwnTargets() throws {
        let fixture = try DetectionFixture()
        try fixture.file("apps/api/pyproject.toml", "[project]")
        try fixture.file("apps/web/package.json", "{}")
        try fixture.file("packages/engine/Cargo.toml", "[package]")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.contains { $0.ide == .pycharm && $0.target == fixture.root.appendingPathComponent("apps/api") })
        #expect(result.candidates.contains { $0.ide == .webstorm && $0.target == fixture.root.appendingPathComponent("apps/web") })
        #expect(result.candidates.contains { $0.ide == .rustrover && $0.target == fixture.root.appendingPathComponent("packages/engine") })
        #expect(result.scannedFileCount == 3)
    }

    @Test func testSwiftPackageTargetsManifest() throws {
        let fixture = try DetectionFixture()
        try fixture.file("Package.swift", "// swift-tools-version: 6.0")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .xcode)
        #expect(result.candidates.first?.target.lastPathComponent == "Package.swift")
    }

    @Test func testAndroidPluginContentDistinguishesAndroidFromPlainGradle() throws {
        let android = try DetectionFixture()
        let jvm = try DetectionFixture()
        try android.file("settings.gradle.kts", "include(\":app\")")
        try android.file("app/build.gradle.kts", "plugins { alias(libs.plugins.android.application) }")
        try jvm.file("build.gradle.kts", "plugins { kotlin(\"jvm\") version \"2.0\" }")

        let androidResult = ProjectDetector().detect(at: android.root)
        let jvmResult = ProjectDetector().detect(at: jvm.root)
        #expect(androidResult.candidates.first?.ide == .androidStudio)
        #expect(androidResult.candidates.first?.target == android.root)
        #expect(jvmResult.candidates.first?.ide == .intellij)
        #expect(!(jvmResult.candidates.contains { $0.ide == .androidStudio }))
    }

    @Test func testIdeaIsDisambiguatedByPythonSDKMetadata() throws {
        let fixture = try DetectionFixture()
        try fixture.file(".idea/misc.xml", "<project><component name=\"ProjectRootManager\" project-jdk-type=\"Python SDK\" project-jdk-name=\"Python 3.13\" /></project>")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .pycharm)
        #expect(result.candidates.first?.target == fixture.root)
        #expect(result.candidates.first?.confidence == 96)
    }

    @Test func testIdeaUsesManifestWithoutAssumingEveryIdeaFolderIsIntelliJ() throws {
        let fixture = try DetectionFixture()
        try fixture.directory(".idea")
        try fixture.file("go.mod", "module example.com/project")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .goland)
        #expect(result.candidates.first?.confidence == 96)
        #expect(!(result.candidates.contains { $0.ide == .intellij }))
    }

    @Test func testUnknownIdeaMetadataExplainsUncertainty() throws {
        let fixture = try DetectionFixture()
        try fixture.file(".idea/misc.xml", "<project />")
        let candidate = ProjectDetector().detect(at: fixture.root).candidates.first
        #expect(candidate?.ide == .intellij)
        #expect(candidate?.reason.contains("unspecified") == true)
        #expect((candidate?.confidence ?? 100) < 90)
    }

    @Test func testSpecializedProjectFamilies() throws {
        let cases: [(String, String, IDEID)] = [
            ("Cargo.toml", "[package]", .rustrover),
            ("go.mod", "module example.com/project", .goland),
            ("composer.json", "{}", .phpstorm),
            ("Gemfile", "source 'https://rubygems.org'", .rubymine),
            ("CMakeLists.txt", "project(example)", .clion),
            ("pom.xml", "<project />", .intellij),
            ("Example.sln", "Microsoft Visual Studio Solution File", .rider),
            ("Example.slnx", "<Solution />", .rider),
            ("Example.Rproj", "Version: 1.0", .rstudio),
            ("pubspec.yaml", "flutter:\n  uses-material-design: true", .androidStudio),
            ("ProjectSettings/ProjectVersion.txt", "m_EditorVersion: 6000.0", .rider),
            ("Example.uproject", "{}", .rider),
            ("DESCRIPTION", "Package: example\nVersion: 1.0", .rstudio)
        ]
        for (path, contents, expected) in cases {
            let fixture = try DetectionFixture()
            try fixture.file(path, contents)
            #expect(ProjectDetector().detect(at: fixture.root).candidates.first?.ide == expected, Comment(rawValue: path))
        }
    }

    @Test func testOtherExplicitEditorConfigurations() throws {
        let cases: [(String, IDEID)] = [
            (".cursor/rules/project.mdc", .cursor), (".windsurf/rules/project.md", .windsurf),
            (".zed/settings.json", .zed), (".fleet/settings.json", .fleet),
            (".nova/Configuration.json", .nova), ("My App.sublime-project", .sublime)
        ]
        for (path, expected) in cases {
            let fixture = try DetectionFixture()
            try fixture.file(path, "{}")
            #expect(ProjectDetector().detect(at: fixture.root).candidates.first?.ide == expected, Comment(rawValue: path))
        }
    }

    @Test func testDependencyAndBuildFoldersDoNotLeakProjectSignals() throws {
        let fixture = try DetectionFixture()
        for path in ["node_modules/example/Package.swift", "Pods/Example/Example.xcodeproj/project.pbxproj", "target/example/Cargo.toml", ".git/package.json", ".venv/lib/example/pyproject.toml"] {
            try fixture.file(path, "")
        }
        try fixture.file("README.md", "# Project")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.scannedFileCount == 1)
        #expect(result.candidates.first?.ide == .vscode)
        #expect(result.candidates.first?.confidence == 10)
        #expect(!(result.candidates.contains { $0.ide == .xcode || $0.ide == .rustrover || $0.ide == .pycharm }))
    }

    @Test func testSymlinkedDirectoriesAndFilesAreNotFollowed() throws {
        let fixture = try DetectionFixture()
        let outside = try DetectionFixture()
        try outside.file("Package.swift", "")
        try outside.directory("App.xcodeproj")
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("external"), withDestinationURL: outside.root)
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("Package.swift"), withDestinationURL: outside.root.appendingPathComponent("Package.swift"))
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(!(result.candidates.contains { $0.ide == .xcode }))
        #expect(result.scannedFileCount == 0)
    }

    @Test func testDepthBudgetStopsDeepTreesAndReportsTruncation() throws {
        let fixture = try DetectionFixture()
        try fixture.file("a/b/c/Package.swift", "")
        try fixture.file("a/b/c/d/e/Cargo.toml", "")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.wasTruncated)
        #expect(result.candidates.contains { $0.ide == .xcode })
        #expect(!(result.candidates.contains { $0.ide == .rustrover }))
    }

    @Test func testContentReadBudgetDoesNotReadArbitrarilyLargeConfigFiles() throws {
        let fixture = try DetectionFixture()
        try fixture.file("build.gradle", String(repeating: " ", count: 70_000) + "com.android.application")
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.wasTruncated)
        #expect(result.candidates.first?.ide == .intellij)
        #expect(!(result.candidates.contains { $0.ide == .androidStudio }))
    }

    @Test func testEntryBudgetPreservesRootManifestBeforeDescendingIntoLargeSourceTree() throws {
        let fixture = try DetectionFixture()
        try fixture.file("Package.swift", "// swift-tools-version: 6.0")
        for index in 0..<6_005 {
            try fixture.file("Sources/source-\(index).txt", "")
        }
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.wasTruncated)
        #expect(result.scannedFileCount <= 6_000)
        #expect(result.candidates.first?.ide == .xcode)
        #expect(result.candidates.first?.target.lastPathComponent == "Package.swift")
    }

    @Test func testEmptyFolderHasHonestGeneralEditorFallback() throws {
        let fixture = try DetectionFixture()
        let result = ProjectDetector().detect(at: fixture.root)
        #expect(result.candidates.first?.ide == .vscode)
        #expect(result.candidates.first?.target == fixture.root)
        #expect(result.candidates.first?.projectKind == "Folder")
        #expect(result.candidates.first?.confidence == 10)
        #expect(result.scannedFileCount == 0)
        #expect(!(result.wasTruncated))
    }

    @Test func testMissingFolderHasNoLaunchCandidates() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(ProjectDetector().detect(at: missing).candidates.isEmpty)
    }

    @Test func testRankingAndIdentifiersAreStableBetweenScans() throws {
        let fixture = try DetectionFixture()
        try fixture.file("apps/one/package.json", "{}")
        try fixture.file("apps/two/package.json", "{}")
        try fixture.file("Cargo.toml", "[package]")
        let first = ProjectDetector().detect(at: fixture.root).candidates
        let second = ProjectDetector().detect(at: fixture.root).candidates
        #expect(first == second)
        #expect(Set(first.map(\.id)).count == first.count)
    }

    @Test func testMatlabFileExtensionIsNotMisidentifiedAsObjectiveC() throws {
        let fixture = try DetectionFixture()
        try fixture.file("calculate.m", "function y = calculate(x)\ny = x * 2;\nend")
        #expect(!(ProjectDetector().detect(at: fixture.root).candidates.contains { $0.ide == .xcode }))
        try fixture.file("App.m", "#import <Foundation/Foundation.h>\n@implementation App\n@end")
        #expect(ProjectDetector().detect(at: fixture.root).candidates.contains { $0.ide == .xcode })
    }

    @Test func testLooseAppleSourceOpensAFileInXcodeRatherThanAnUnsupportedFolder() throws {
        let fixture = try DetectionFixture()
        try fixture.file("Sources/Main.swift", "print(\"Hello\")")
        let xcode = try #require(ProjectDetector().detect(at: fixture.root).candidates.first { $0.ide == .xcode })
        #expect(xcode.target == fixture.root.appendingPathComponent("Sources/Main.swift"))
    }

    @Test func testGenericFallbackIsClearlyMarked() throws {
        let fixture = try DetectionFixture()
        #expect(ProjectDetector().detect(at: fixture.root).candidates.allSatisfy { $0.isGenericFallback })
        try fixture.file("package.json", "{}")
        #expect(ProjectDetector().detect(at: fixture.root).candidates.first?.isGenericFallback == false)
    }
}

private final class DetectionFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Twig Detection \(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func directory(_ path: String) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
    }

    func file(_ path: String, _ contents: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}
