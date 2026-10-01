import AppKit
import Observation
import TwigCore

@MainActor
@Observable
final class TwigStore {
    private(set) var items: [ScannedWorktree] = []
    private(set) var preferences = TwigPreferences()
    private(set) var installed: Set<IDEID> = []
    private(set) var isRefreshing = false
    private(set) var openingID: String?
    private(set) var lastRefreshed: Date?
    private(set) var warnings: [String] = []
    private(set) var preferencesNeedRecovery = false
    var errorMessage: String?
    var selectedID: String?
    var search = ""
    private let scanner = WorktreeScanner()
    private let workspace = WorkspaceService()
    private let persistence: FilePreferencesStore
    private var refreshAgain = false

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        persistence = FilePreferencesStore(storageURL: support.appendingPathComponent("Twig/preferences.json"))
        do { preferences = try persistence.load() }
        catch {
            preferencesNeedRecovery = true
            errorMessage = "Could not read Twig preferences. \(error.localizedDescription)"
        }
    }

    var codexHome: URL {
        let path = preferences.codexHome
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
    }

    var sortedItems: [ScannedWorktree] {
        items.sorted {
            let left = activityDate(for: $0), right = activityDate(for: $1)
            return left == right ? $0.id < $1.id : left > right
        }
    }

    var filteredItems: [ScannedWorktree] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return sortedItems.filter {
            query.isEmpty || [$0.worktree.repositoryName, $0.worktree.branch ?? "detached",
                              $0.worktree.folder.path, editorName(for: $0)]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var selectedItem: ScannedWorktree? { items.first { $0.id == selectedID } }

    func activityDate(for item: ScannedWorktree) -> Date {
        max(item.worktree.lastActivity, preferences.lastOpened[WorktreePath.key(for: item.worktree.folder)] ?? .distantPast)
    }

    func override(for item: ScannedWorktree) -> WorktreeOverride? {
        preferences.overrides[WorktreePath.key(for: item.worktree.folder)]
    }

    func resolution(for item: ScannedWorktree) -> LaunchResolution {
        LaunchResolver.resolve(folder: item.worktree.folder, detection: item.detection,
                               installed: installed, override: override(for: item), fallbackIDE: preferences.fallbackIDE)
    }

    func editorName(for item: ScannedWorktree) -> String {
        switch resolution(for: item).destination {
        case .ide(let ide): ide.displayName
        case .missingApp(let ide): "\(ide.displayName) unavailable"
        case .finder: "Finder"
        }
    }

    func refreshApplications() async {
        await workspace.refreshApplications()
        installed = Set(workspace.applications.keys)
    }

    func refresh() async {
        guard !isRefreshing else { refreshAgain = true; return }
        isRefreshing = true
        repeat {
            refreshAgain = false
            await refreshApplications()
            let root = codexHome
            let snapshot = await scanner.scan(codexHome: root)
            guard !Task.isCancelled else { isRefreshing = false; return }
            if codexHome != root { refreshAgain = true; continue }
            items = snapshot.items
            warnings = snapshot.warnings
            lastRefreshed = Date()
        } while refreshAgain
        isRefreshing = false
    }

    func monitor() async {
        await refresh()
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            await refresh()
        }
    }

    func open(_ item: ScannedWorktree) async {
        guard openingID == nil else { return }
        openingID = item.id
        defer { openingID = nil }
        await refreshApplications()
        do {
            try await workspace.open(resolution(for: item))
            var updated = preferences
            updated.lastOpened[WorktreePath.key(for: item.worktree.folder)] = Date()
            save(updated)
        } catch { errorMessage = error.localizedDescription }
    }

    func setOverride(_ override: WorktreeOverride?, for item: ScannedWorktree) {
        var updated = preferences
        updated.overrides[WorktreePath.key(for: item.worktree.folder)] = override
        save(updated)
    }

    func setFallback(_ ide: IDEID?) {
        var updated = preferences
        updated.fallbackIDE = ide
        save(updated)
    }

    func setCodexHome(_ path: String) {
        let cleaned = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            let expanded = (cleaned as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard expanded.hasPrefix("/"), FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
                errorMessage = "Choose an existing Codex home folder, such as ~/.codex."
                return
            }
        }
        var updated = preferences
        updated.codexHome = cleaned.isEmpty ? nil : cleaned
        if save(updated) { Task { await refresh() } }
    }

    func openFolder(_ item: ScannedWorktree) {
        do { try workspace.openFolder(item.worktree.folder) }
        catch { errorMessage = error.localizedDescription }
    }
    func reveal(_ item: ScannedWorktree) { workspace.reveal(item.worktree.folder) }
    func copyPath(_ item: ScannedWorktree) { workspace.copyPath(item.worktree.folder) }

    func recoverPreferences() {
        do {
            if FileManager.default.fileExists(atPath: persistence.storageURL.path) {
                let backup = persistence.storageURL.appendingPathExtension("backup-\(UUID().uuidString)")
                try FileManager.default.copyItem(at: persistence.storageURL, to: backup)
            }
            let defaults = TwigPreferences()
            try persistence.reset(defaults)
            preferences = defaults
            preferencesNeedRecovery = false
            errorMessage = nil
            Task { await refresh() }
        } catch { errorMessage = "Could not recover preferences: \(error.localizedDescription)" }
    }

    @discardableResult
    private func save(_ value: TwigPreferences) -> Bool {
        do { try persistence.save(value); preferences = value; return true }
        catch { errorMessage = "Could not save Twig preferences. \(error.localizedDescription)"; return false }
    }
}
