import Foundation

/// Small, side-effect-free descriptions of facts already known about a worktree.
public enum WorktreePresentation {
    private static let editorContainers = Set(IDEID.allCases.map { "\($0.displayName) project" })
        .union(["JetBrains project", "IntelliJ project"])

    /// Describe the target that will actually open, rather than another project in the checkout.
    public static func projectType(detection: ProjectDetection, resolution: LaunchResolution) -> String? {
        let target = resolution.target.standardizedFileURL.path
        if let candidate = resolution.candidate,
           candidate.target.standardizedFileURL.path == target,
           let kind = usefulProjectType(candidate) {
            return kind
        }

        // An explicit target can differ from the resolver's first candidate for that editor.
        // Editor metadata may also outrank a useful manifest at the same target.
        return detection.candidates.enumerated()
            .filter { $0.element.target.standardizedFileURL.path == target }
            .sorted {
                $0.element.confidence == $1.element.confidence
                    ? $0.offset < $1.offset : $0.element.confidence > $1.element.confidence
            }
            .compactMap { usefulProjectType($0.element) }.first
    }

    /// Uses successful opens only. Filesystem activity is not evidence that a person opened a project.
    public static func lastOpenedLabel(_ date: Date?, now: Date = Date()) -> String? {
        guard let date else { return nil }
        let interval = now.timeIntervalSince(date)
        guard interval.isFinite else { return nil }
        // A clock adjustment must not turn a successful open into a future-time claim.
        let seconds = max(0, interval)
        if seconds < 60 { return "Opened just now" }
        if seconds < 3_600 { return "Opened \(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "Opened \(Int(seconds / 3_600))h ago" }
        if seconds < 604_800 { return "Opened \(Int(seconds / 86_400))d ago" }
        if seconds < 31_536_000 { return "Opened \(Int(seconds / 604_800))w ago" }
        return "Opened \(Int(seconds / 31_536_000))y ago"
    }

    private static func usefulProjectType(_ candidate: ProjectCandidate) -> String? {
        let kind = candidate.projectKind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kind.isEmpty, !candidate.isGenericFallback,
              kind != "Folder", !kind.lowercased().hasSuffix(" folder") else { return nil }
        // A language inferred from a manifest is useful; an editor's settings directory is not.
        // Actual project files such as .xcodeproj and .ipr still describe a concrete launch format.
        let concreteEditorFile = ["xcodeproj", "ipr"].contains(candidate.target.pathExtension.lowercased())
        guard concreteEditorFile || !editorContainers.contains(kind) else { return nil }
        switch kind {
        case "JavaScript / TypeScript": return "JS / TS"
        default: return kind
        }
    }
}
