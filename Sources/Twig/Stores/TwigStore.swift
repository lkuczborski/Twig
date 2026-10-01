import AppKit
import Observation
import TwigCore
import TwigSync

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
    @ObservationIgnored private var syncState = RefreshState()
    @ObservationIgnored private let watcher = FileEventWatcher()
    @ObservationIgnored private var routing: ChangeRouting?
    @ObservationIgnored private var watchedPaths: [String] = []
    @ObservationIgnored private var visibleSurfaces: Set<String> = []
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycle: WorkspaceNotifications?
    @ObservationIgnored private var hasApplicationCatalog = false
    @ObservationIgnored private var refreshWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var isWatching = false

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        persistence = FilePreferencesStore(storageURL: support.appendingPathComponent("Twig/preferences.json"))
        do { preferences = try persistence.load() }
        catch {
            preferencesNeedRecovery = true
            errorMessage = "Could not read Twig preferences. \(error.localizedDescription)"
        }
        configureWatcher()
        lifecycle = WorkspaceNotifications(
            center: NSWorkspace.shared.notificationCenter,
            wakeName: NSWorkspace.didWakeNotification, sleepName: NSWorkspace.willSleepNotification,
            onWake: { [weak self] in Task { @MainActor in self?.didWake() } },
            onSleep: { [weak self] in Task { @MainActor in self?.willSleep() } }
        )
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
        hasApplicationCatalog = true
    }

    func contentVisibilityChanged(_ surface: String, isVisible: Bool) {
        if isVisible { visibleSurfaces.insert(surface) }
        else { visibleSurfaces.remove(surface) }
        syncState.isVisible = !visibleSurfaces.isEmpty
        if isVisible {
            // A failed watcher falls back to checking on presentation, never a timer.
            if !isWatching { syncState.invalidate(.full); configureWatcher() }
            Task { await processPending() }
        } else if !syncState.isVisible {
            debounceTask?.cancel()
            debounceTask = nil
        }
    }

    func refresh() async {
        syncState.invalidate(.full)
        await processPending(allowWhileHidden: true)
    }

    private func processPending(allowWhileHidden: Bool = false) async {
        guard !Task.isCancelled else { return }
        if isRefreshing {
            await withCheckedContinuation { refreshWaiters.append($0) }
            await processPending(allowWhileHidden: allowWhileHidden)
            return
        }
        guard !syncState.pending.isEmpty, syncState.isVisible || allowWhileHidden else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            let waiting = refreshWaiters
            refreshWaiters.removeAll()
            for continuation in waiting { continuation.resume() }
        }
        while let request = syncState.takePending(allowWhileHidden: allowWhileHidden) {
            let baseline = FileEventWatcher.currentEventID
            if request.applications || !hasApplicationCatalog { await refreshApplications() }
            if request.worktrees {
                let root = codexHome
                let snapshot = await scanner.scan(
                    codexHome: root,
                    invalidatedWorktrees: request.allProjects ? nil : request.projectIDs
                )
                if Task.isCancelled { syncState.invalidate(request); return }
                if codexHome != root { syncState.invalidate(.full); continue }
                items = snapshot.items
                warnings = snapshot.warnings
                lastRefreshed = Date()
            }
            configureWatcher(force: request.reconfigureWatcher, since: baseline)
        }
    }

    private func configureWatcher(force: Bool = false, since baseline: UInt64? = nil) {
        let configuration = ChangeRouting(
            worktreesRoot: codexHome.appendingPathComponent("worktrees", isDirectory: true),
            worktrees: items.map {
                WatchedWorktree(id: $0.id, folder: $0.worktree.folder,
                                gitDirectory: $0.worktree.gitDirectory,
                                commonGitDirectory: $0.worktree.commonGitDirectory)
            },
            applicationDirectories: InstalledApplicationScanner.standardDirectories
        )
        routing = configuration
        let roots = configuration.watchRoots
        let paths = roots.map(\.path)
        guard force || !isWatching || paths != watchedPaths else { return }
        do {
            try watcher.start(paths: roots, since: baseline) { [weak self] events in
                Task { @MainActor in self?.filesystemChanged(events) }
            }
            watchedPaths = paths
            isWatching = true
        } catch {
            watchedPaths = []
            isWatching = false
            errorMessage = error.localizedDescription
        }
    }

    private func filesystemChanged(_ events: [FilesystemEvent]) {
        guard isWatching, let routing else { return }
        let request = routing.classify(events)
        guard !request.isEmpty else { return }
        syncState.invalidate(request)
        scheduleIfVisible()
    }

    private func scheduleIfVisible() {
        guard syncState.isVisible else { return }
        // One short debounce is created only in response to an actual change.
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.processPending()
        }
    }

    private func didWake() {
        syncState.invalidate(.full)
        configureWatcher(force: true)
        scheduleIfVisible()
    }

    private func willSleep() {
        debounceTask?.cancel()
        watcher.stop()
        watchedPaths = []
        isWatching = false
    }

    private func discoverySettingsChanged() {
        syncState.invalidate(.full)
        configureWatcher(force: true)
        scheduleIfVisible()
    }

    func open(_ item: ScannedWorktree) async {
        guard openingID == nil else { return }
        openingID = item.id
        defer { openingID = nil }
        await processPending(allowWhileHidden: true)
        let current = items.first { $0.id == item.id } ?? item
        do {
            try await workspace.open(resolution(for: current))
            var updated = preferences
            updated.lastOpened[WorktreePath.key(for: current.worktree.folder)] = Date()
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
        if save(updated) { discoverySettingsChanged() }
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
            discoverySettingsChanged()
        } catch { errorMessage = "Could not recover preferences: \(error.localizedDescription)" }
    }

    @discardableResult
    private func save(_ value: TwigPreferences) -> Bool {
        do { try persistence.save(value); preferences = value; return true }
        catch { errorMessage = "Could not save Twig preferences. \(error.localizedDescription)"; return false }
    }
}
