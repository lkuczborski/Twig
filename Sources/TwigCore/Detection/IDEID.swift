import Foundation

/// Stable persistence identifiers; application bundle identifiers are deliberately separate.
public enum IDEID: String, Codable, CaseIterable, Sendable {
    case xcode, vscode, cursor, windsurf, zed, sublime
    case intellij, androidStudio, pycharm, webstorm, phpstorm, rubymine
    case goland, clion, rider, rustrover, fleet, nova, rstudio

    public var displayName: String {
        switch self {
        case .xcode: "Xcode"
        case .vscode: "Visual Studio Code"
        case .cursor: "Cursor"
        case .windsurf: "Windsurf"
        case .zed: "Zed"
        case .sublime: "Sublime Text"
        case .intellij: "IntelliJ IDEA"
        case .androidStudio: "Android Studio"
        case .pycharm: "PyCharm"
        case .webstorm: "WebStorm"
        case .phpstorm: "PhpStorm"
        case .rubymine: "RubyMine"
        case .goland: "GoLand"
        case .clion: "CLion"
        case .rider: "Rider"
        case .rustrover: "RustRover"
        case .fleet: "Fleet"
        case .nova: "Nova"
        case .rstudio: "RStudio"
        }
    }

    public var bundleIdentifiers: [String] {
        switch self {
        case .xcode: ["com.apple.dt.Xcode"]
        case .vscode: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"]
        case .cursor: ["com.todesktop.230313mzl4w4u92"]
        case .windsurf: ["com.exafunction.windsurf", "com.exafunction.windsurfNext"]
        case .zed: ["dev.zed.Zed", "dev.zed.Zed-Preview", "dev.zed.Zed-Nightly"]
        case .sublime: ["com.sublimetext.4", "com.sublimetext.3"]
        case .intellij: ["com.jetbrains.intellij", "com.jetbrains.intellij.ce"]
        case .androidStudio: ["com.google.android.studio"]
        case .pycharm: ["com.jetbrains.pycharm", "com.jetbrains.pycharm.ce"]
        case .webstorm: ["com.jetbrains.WebStorm"]
        case .phpstorm: ["com.jetbrains.PhpStorm"]
        case .rubymine: ["com.jetbrains.rubymine"]
        case .goland: ["com.jetbrains.goland"]
        case .clion: ["com.jetbrains.CLion"]
        case .rider: ["com.jetbrains.rider"]
        case .rustrover: ["com.jetbrains.rustrover"]
        case .fleet: ["com.jetbrains.fleet"]
        case .nova: ["com.panic.Nova"]
        case .rstudio: ["com.rstudio.desktop", "org.rstudio.RStudio"]
        }
    }
}

public struct ProjectCandidate: Identifiable, Hashable, Sendable {
    public var id: String { "\(ide.rawValue):\(target.standardizedFileURL.path)" }
    public var isGenericFallback: Bool { projectKind == "Folder" && confidence <= 10 }
    public let ide: IDEID
    public let target: URL
    public let projectKind: String
    public let reason: String
    /// A relative evidence score, not a probability that this is the user's preferred editor.
    /// Scores 0...10 are generic folder fallbacks; project evidence always scores above 10.
    public let confidence: Int

    public init(ide: IDEID, target: URL, projectKind: String, reason: String, confidence: Int) {
        self.ide = ide
        self.target = target.standardizedFileURL
        self.projectKind = projectKind
        self.reason = reason
        self.confidence = min(100, max(0, confidence))
    }
}

public struct ProjectDetection: Sendable {
    public let candidates: [ProjectCandidate]
    public let scannedFileCount: Int
    public let wasTruncated: Bool

    public init(candidates: [ProjectCandidate], scannedFileCount: Int, wasTruncated: Bool) {
        self.candidates = candidates
        self.scannedFileCount = scannedFileCount
        self.wasTruncated = wasTruncated
    }
}
