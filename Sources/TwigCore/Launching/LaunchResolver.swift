import Foundation

/// A worktree-specific editor choice. A nil override means automatic detection.
public struct WorktreeOverride: Codable, Hashable, Sendable {
    public var ide: IDEID
    /// Optional absolute or worktree-relative project path selected by the user.
    public var targetPath: String?

    public init(ide: IDEID, targetPath: String? = nil) {
        self.ide = ide
        self.targetPath = targetPath
    }
}

public enum LaunchDestination: Hashable, Sendable {
    case ide(IDEID)
    case finder
    /// An explicit preference must never silently launch a different app.
    case missingApp(IDEID)
}

public struct LaunchResolution: Hashable, Sendable {
    public let destination: LaunchDestination
    public let target: URL
    public let reason: String
    public let candidate: ProjectCandidate?
    public let isOverride: Bool

    public init(destination: LaunchDestination, target: URL, reason: String,
                candidate: ProjectCandidate? = nil, isOverride: Bool = false) {
        self.destination = destination
        self.target = target
        self.reason = reason
        self.candidate = candidate
        self.isOverride = isOverride
    }
}

/// Pure policy: filesystem scanning and actually opening apps remain separate concerns.
public enum LaunchResolver {
    public static func resolve(
        folder: URL,
        detection: ProjectDetection,
        installed: Set<IDEID>,
        override: WorktreeOverride? = nil,
        fallbackIDE: IDEID? = nil
    ) -> LaunchResolution {
        let candidates = detection.candidates.enumerated().sorted {
            if $0.element.confidence != $1.element.confidence {
                return $0.element.confidence > $1.element.confidence
            }
            return $0.offset < $1.offset
        }.map(\.element)

        if let override {
            let candidate = candidates.first { $0.ide == override.ide }
            let target = override.targetPath.flatMap { containedTarget($0, folder: folder) }
                ?? safeTarget(candidate?.target, folder: folder)
            return LaunchResolution(
                destination: installed.contains(override.ide) ? .ide(override.ide) : .missingApp(override.ide),
                target: target,
                reason: installed.contains(override.ide)
                    ? "Your editor choice for this worktree"
                    : "Your chosen editor, \(override.ide.displayName), is not installed",
                candidate: candidate,
                isOverride: true
            )
        }

        if let candidate = candidates.first(where: { !$0.isGenericFallback && installed.contains($0.ide) }) {
            return LaunchResolution(
                destination: .ide(candidate.ide),
                target: safeTarget(candidate.target, folder: folder),
                reason: candidate.reason,
                candidate: candidate
            )
        }

        if let fallbackIDE, installed.contains(fallbackIDE) {
            return LaunchResolution(
                destination: .ide(fallbackIDE), target: folder,
                reason: "Your default editor; no installed project-specific editor was found"
            )
        }

        if let candidate = candidates.first(where: { installed.contains($0.ide) }) {
            return LaunchResolution(
                destination: .ide(candidate.ide),
                target: safeTarget(candidate.target, folder: folder),
                reason: candidate.reason,
                candidate: candidate
            )
        }

        return LaunchResolution(
            destination: .finder, target: folder,
            reason: "No matching installed editor; open this worktree in Finder"
        )
    }

    private static func containedTarget(_ path: String, folder: URL) -> URL? {
        let target: URL
        if (path as NSString).isAbsolutePath {
            target = URL(fileURLWithPath: path)
        } else {
            target = folder.appendingPathComponent(path)
        }
        let root = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let normalized = target.standardizedFileURL.resolvingSymlinksInPath()
        return normalized.pathComponents.starts(with: root) ? normalized : nil
    }

    private static func safeTarget(_ target: URL?, folder: URL) -> URL {
        guard let target, target.isFileURL else { return folder }
        return containedTarget(target.path, folder: folder) ?? folder
    }
}
