import Foundation

public struct ScannedWorktree: Identifiable, Sendable {
    public let worktree: Worktree
    public let detection: ProjectDetection
    public var id: String { worktree.id }
}

public struct ScanSnapshot: Sendable {
    public let items: [ScannedWorktree]
    public let warnings: [String]
    /// Useful for verifying that a metadata-only refresh reuses project inference.
    public let detectionsPerformed: Int
}

/// Serializes filesystem work and retains project detection until its checkout changes.
public actor WorktreeScanner {
    private var cachedHome: URL?
    private var detections: [String: ProjectDetection] = [:]

    public init() {}

    /// nil invalidation forces project detection; an empty set refreshes Git/activity only.
    public func scan(codexHome: URL, invalidatedWorktrees: Set<String>? = nil) -> ScanSnapshot {
        let home = codexHome.standardizedFileURL.resolvingSymlinksInPath()
        if home != cachedHome { detections.removeAll(); cachedHome = home }
        let result = WorktreeDiscoverer().discover(in: home)
        let detector = ProjectDetector()
        var items: [ScannedWorktree] = []
        var performed = 0
        for worktree in result.worktrees {
            if Task.isCancelled { break }
            let detection: ProjectDetection
            if let cached = detections[worktree.id], let invalidatedWorktrees,
               !invalidatedWorktrees.contains(worktree.id) {
                detection = cached
            } else {
                detection = detector.detect(at: worktree.folder)
                detections[worktree.id] = detection
                performed += 1
            }
            items.append(ScannedWorktree(worktree: worktree, detection: detection))
        }
        let activeIDs = Set(result.worktrees.map(\.id))
        detections = detections.filter { activeIDs.contains($0.key) }
        return ScanSnapshot(items: items, warnings: result.warnings, detectionsPerformed: performed)
    }
}
