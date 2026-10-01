import Foundation
import TwigCore

struct ScannedWorktree: Identifiable, Sendable {
    let worktree: Worktree
    let detection: ProjectDetection
    var id: String { worktree.id }
}

struct ScanSnapshot: Sendable {
    let items: [ScannedWorktree]
    let warnings: [String]
}

/// Filesystem traversal stays off the main actor, with one scan running at a time.
actor WorktreeScanner {
    func scan(codexHome: URL) -> ScanSnapshot {
        let result = WorktreeDiscoverer().discover(in: codexHome)
        let detector = ProjectDetector()
        var items: [ScannedWorktree] = []
        for worktree in result.worktrees {
            if Task.isCancelled { break }
            items.append(ScannedWorktree(worktree: worktree, detection: detector.detect(at: worktree.folder)))
        }
        return ScanSnapshot(items: items, warnings: result.warnings)
    }
}
