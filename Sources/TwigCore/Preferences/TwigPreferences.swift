import Foundation

public enum WorktreePath {
    /// Stable keys let repeated scans and paths containing `..` share a preference.
    public static func key(for folder: URL) -> String {
        folder.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

public struct TwigPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var codexHome: String?
    public var repositoryRoots: [String]
    public var fallbackIDE: IDEID?
    public var overrides: [String: WorktreeOverride]
    public var lastOpened: [String: Date]
    public var hasCompletedWelcome: Bool
    public var repositoryEditors: [String: IDEID]
    public var pinnedWorktrees: Set<String>
    public var worktreeLabels: [String: String]
    public var groupByRepository: Bool
    public var globalShortcut: GlobalShortcut?

    public init(codexHome: String? = nil, fallbackIDE: IDEID? = nil,
                overrides: [String: WorktreeOverride] = [:], lastOpened: [String: Date] = [:],
                pinnedWorktrees: Set<String> = [], worktreeLabels: [String: String] = [:],
                groupByRepository: Bool = true, repositoryEditors: [String: IDEID] = [:],
                hasCompletedWelcome: Bool = false, globalShortcut: GlobalShortcut? = .default, repositoryRoots: [String] = []) {
        self.codexHome = codexHome
        self.repositoryRoots = repositoryRoots
        self.fallbackIDE = fallbackIDE
        self.overrides = overrides
        self.lastOpened = lastOpened
        self.hasCompletedWelcome = hasCompletedWelcome
        self.repositoryEditors = repositoryEditors
        self.pinnedWorktrees = pinnedWorktrees
        self.worktreeLabels = worktreeLabels
        self.groupByRepository = groupByRepository
        self.globalShortcut = globalShortcut
    }

    public func overrideForWorktree(_ folder: URL) -> WorktreeOverride? {
        overrides[WorktreePath.key(for: folder)]
    }

    public mutating func setOverride(_ override: WorktreeOverride?, for folder: URL) {
        overrides[WorktreePath.key(for: folder)] = override
    }

    public func lastOpenedDate(for folder: URL) -> Date? {
        lastOpened[WorktreePath.key(for: folder)]
    }

    public mutating func recordOpened(_ folder: URL, at date: Date = Date()) {
        lastOpened[WorktreePath.key(for: folder)] = date
    }

    public func editorForRepository(_ worktree: Worktree) -> IDEID? {
        repositoryEditors[RepositoryIdentity.key(for: worktree)]
    }

    public mutating func setEditor(_ ide: IDEID?, forRepository worktree: Worktree) {
        repositoryEditors[RepositoryIdentity.key(for: worktree)] = ide
    }

    public func isPinned(_ folder: URL) -> Bool {
        pinnedWorktrees.contains(WorktreePath.key(for: folder))
    }

    public mutating func setPinned(_ pinned: Bool, for folder: URL) {
        let key = WorktreePath.key(for: folder)
        if pinned { pinnedWorktrees.insert(key) }
        else { pinnedWorktrees.remove(key) }
    }

    public func label(for folder: URL) -> String? {
        worktreeLabels[WorktreePath.key(for: folder)]
    }

    public mutating func setLabel(_ label: String, for folder: URL) {
        let cleaned = label.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        worktreeLabels[WorktreePath.key(for: folder)] = cleaned.isEmpty ? nil : cleaned
    }

    public func previousWorktreeID(among ids: Set<String>) -> String? {
        let recent = lastOpened.filter { ids.contains($0.key) }.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }
        return recent.dropFirst().first?.key ?? recent.first?.key
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, codexHome, fallbackIDE, overrides, lastOpened, repositoryRoots
        case hasCompletedWelcome, repositoryEditors, globalShortcut
        case pinnedWorktrees, worktreeLabels, groupByRepository
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version == Self.currentSchemaVersion else {
            throw PreferencesStoreError.unsupportedVersion(version)
        }
        repositoryRoots = try container.decodeIfPresent([String].self, forKey: .repositoryRoots) ?? []
        codexHome = try container.decodeIfPresent(String.self, forKey: .codexHome)
        fallbackIDE = try container.decodeIfPresent(IDEID.self, forKey: .fallbackIDE)
        overrides = try container.decodeIfPresent([String: WorktreeOverride].self, forKey: .overrides) ?? [:]
        lastOpened = try container.decodeIfPresent([String: Date].self, forKey: .lastOpened) ?? [:]
        hasCompletedWelcome = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedWelcome) ?? false
        repositoryEditors = try container.decodeIfPresent([String: IDEID].self, forKey: .repositoryEditors) ?? [:]
        pinnedWorktrees = try container.decodeIfPresent(Set<String>.self, forKey: .pinnedWorktrees) ?? []
        worktreeLabels = try container.decodeIfPresent([String: String].self, forKey: .worktreeLabels) ?? [:]
        globalShortcut = container.contains(.globalShortcut)
            ? try container.decodeIfPresent(GlobalShortcut.self, forKey: .globalShortcut) : .default
        groupByRepository = try container.decodeIfPresent(Bool.self, forKey: .groupByRepository) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repositoryRoots, forKey: .repositoryRoots)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(codexHome, forKey: .codexHome)
        try container.encodeIfPresent(fallbackIDE, forKey: .fallbackIDE)
        try container.encode(overrides, forKey: .overrides)
        try container.encode(lastOpened, forKey: .lastOpened)
        try container.encode(hasCompletedWelcome, forKey: .hasCompletedWelcome)
        try container.encode(repositoryEditors, forKey: .repositoryEditors)
        try container.encode(pinnedWorktrees.sorted(), forKey: .pinnedWorktrees)
        try container.encode(worktreeLabels, forKey: .worktreeLabels)
        try container.encode(groupByRepository, forKey: .groupByRepository)
        try container.encode(globalShortcut, forKey: .globalShortcut)
    }
}
