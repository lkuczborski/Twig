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
    public var fallbackIDE: IDEID?
    public var overrides: [String: WorktreeOverride]
    public var lastOpened: [String: Date]

    public init(codexHome: String? = nil, fallbackIDE: IDEID? = nil,
                overrides: [String: WorktreeOverride] = [:], lastOpened: [String: Date] = [:]) {
        self.codexHome = codexHome
        self.fallbackIDE = fallbackIDE
        self.overrides = overrides
        self.lastOpened = lastOpened
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

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, codexHome, fallbackIDE, overrides, lastOpened
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version == Self.currentSchemaVersion else {
            throw PreferencesStoreError.unsupportedVersion(version)
        }
        codexHome = try container.decodeIfPresent(String.self, forKey: .codexHome)
        fallbackIDE = try container.decodeIfPresent(IDEID.self, forKey: .fallbackIDE)
        overrides = try container.decodeIfPresent([String: WorktreeOverride].self, forKey: .overrides) ?? [:]
        lastOpened = try container.decodeIfPresent([String: Date].self, forKey: .lastOpened) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(codexHome, forKey: .codexHome)
        try container.encodeIfPresent(fallbackIDE, forKey: .fallbackIDE)
        try container.encode(overrides, forKey: .overrides)
        try container.encode(lastOpened, forKey: .lastOpened)
    }
}
