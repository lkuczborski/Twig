import Foundation

public enum PreferencesStoreError: Error, LocalizedError, Equatable {
    case unreadable(String)
    case invalidData(String)
    case unsupportedVersion(Int)
    case resetRequired

    public var errorDescription: String? {
        switch self {
        case .unreadable(let detail): "Twig could not read its saved preferences. \(detail)"
        case .invalidData(let detail): "Twig's saved preferences could not be decoded. \(detail)"
        case .unsupportedVersion(let version): "These preferences require a newer Twig version (format \(version))."
        case .resetRequired: "Saved preferences were not readable. Reset them explicitly before saving changes."
        }
    }
}

public protocol PreferencesPersisting: AnyObject {
    func load() throws -> TwigPreferences
    func save(_ preferences: TwigPreferences) throws
    func reset(_ preferences: TwigPreferences) throws
}

/// Synchronous, small-file persistence. Own this store from a single actor (the UI uses MainActor).
/// Failed reads never cause an automatic write of defaults over a user's existing settings.
public final class FilePreferencesStore: PreferencesPersisting {
    public let storageURL: URL
    private var hasLoaded = false
    private var requiresReset = false

    public static var defaultStorageURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Twig", isDirectory: true)
            .appendingPathComponent("preferences.json")
    }

    public init(storageURL: URL = FilePreferencesStore.defaultStorageURL) {
        self.storageURL = storageURL
    }

    public func load() throws -> TwigPreferences {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            hasLoaded = true
            requiresReset = false
            return TwigPreferences()
        }

        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            requiresReset = true
            throw PreferencesStoreError.unreadable(error.localizedDescription)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let preferences = try decoder.decode(TwigPreferences.self, from: data)
            hasLoaded = true
            requiresReset = false
            return preferences
        } catch {
            requiresReset = true
            if let error = error as? PreferencesStoreError { throw error }
            throw PreferencesStoreError.invalidData(error.localizedDescription)
        }
    }

    public func save(_ preferences: TwigPreferences) throws {
        guard !requiresReset else { throw PreferencesStoreError.resetRequired }
        // Even callers that skip load cannot overwrite an unreadable file by accident.
        if !hasLoaded { _ = try load() }
        try write(preferences)
    }

    /// The explicit recovery action. Ordinary saves remain blocked after a failed load.
    public func reset(_ preferences: TwigPreferences = TwigPreferences()) throws {
        try write(preferences)
        hasLoaded = true
        requiresReset = false
    }

    private func write(_ preferences: TwigPreferences) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(preferences)
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: storageURL, options: .atomic)
    }
}
