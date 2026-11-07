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
    private(set) var repositoryStatuses: [RepositoryRootStatus] = []
    private(set) var isAddingRepository = false
    private(set) var preferencesNeedRecovery = false
    var errorMessage: String?
    var selectedID: String?
    var highlightedID: String?
    var search = ""
    var shortcutError: String?
    @ObservationIgnored var onGlobalShortcutChange: ((GlobalShortcut?) -> String?)?
    private let scanner = WorktreeScanner()
    private let workspace = WorkspaceService()
    @ObservationIgnored private let gitStatusStore = WorktreeGitStatusStore()
    private var editorIcons: [IDEID: NSImage] = [:]
    private var finderIcon: NSImage?
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
        var preferencesURL = support.appendingPathComponent("Twig/preferences.json")
#if TWIG_PREVIEW
        preferencesURL = PreviewEnvironment.preferencesURL ?? preferencesURL
#endif
        persistence = FilePreferencesStore(storageURL: preferencesURL)
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

    var repositoryRoots: [URL] {
        var seen: Set<String> = []
        return preferences.repositoryRoots.map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        }.filter { seen.insert($0.path).inserted }
    }

    var filteredItems: [ScannedWorktree] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedItems }
        return sortedItems.enumerated().compactMap { index, item -> (ScannedWorktree, Int, Int)? in
            guard let score = WorktreeSearch.score(query: query, fields: [label(for: item) ?? "", item.worktree.repositoryName,
                item.worktree.branch ?? "detached", editorName(for: item)],
                literalFields: [item.worktree.folder.path]) else { return nil }
            return (item, score, index)
        }.sorted { $0.1 == $1.1 ? $0.2 < $1.2 : $0.1 > $1.1 }.map { $0.0 }
    }

    var highlightedItem: ScannedWorktree? {
        let results = visibleItems
        let id = WorktreeSelection.resolved(highlightedID, in: results.map(\.id))
        return results.first { $0.id == id }
    }

    var previousItem: ScannedWorktree? {
        let id = preferences.previousWorktreeID(among: Set(items.map(\.id)))
        return items.first { $0.id == id }
    }

    func reconcileHighlight() {
        highlightedID = WorktreeSelection.resolved(highlightedID, in: visibleItems.map(\.id))
    }

    func moveHighlight(by offset: Int) {
        highlightedID = WorktreeSelection.moved(highlightedItem?.id, by: offset, in: visibleItems.map(\.id))
    }

    func openHighlighted() async {
        if let item = highlightedItem { await open(item) }
    }

    func openPrevious() async {
        await processPending(allowWhileHidden: true)
        if let item = previousItem { await open(item) }
    }

    var selectedItem: ScannedWorktree? { items.first { $0.id == selectedID } }

    var worktreeSections: [WorktreeSection] {
        // Search results stay flat so ranking and keyboard navigation can agree.
        let searching = !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return WorktreeOrganization.sections(
            filteredItems.map(\.worktree),
            pinnedIDs: searching ? [] : preferences.pinnedWorktrees,
            groupByRepository: !searching && preferences.groupByRepository
        )
    }

    var visibleItems: [ScannedWorktree] {
        let byID = Dictionary(uniqueKeysWithValues: filteredItems.map { ($0.id, $0) })
        return worktreeSections.flatMap(\.worktrees).compactMap { byID[$0.id] }
    }

    func label(for item: ScannedWorktree) -> String? { preferences.label(for: item.worktree.folder) }
    func displayTitle(for item: ScannedWorktree) -> String { label(for: item) ?? item.worktree.repositoryName }
    func isPinned(_ item: ScannedWorktree) -> Bool { preferences.isPinned(item.worktree.folder) }

    func togglePin(_ item: ScannedWorktree) {
        var updated = preferences
        updated.setPinned(!isPinned(item), for: item.worktree.folder)
        save(updated)
    }

    @discardableResult
    func setLabel(_ label: String, for item: ScannedWorktree) -> Bool {
        var updated = preferences
        updated.setLabel(label, for: item.worktree.folder)
        return save(updated)
    }

    func setGroupByRepository(_ grouped: Bool) {
        var updated = preferences
        updated.groupByRepository = grouped
        save(updated)
    }

    func activityDate(for item: ScannedWorktree) -> Date {
        max(item.worktree.lastActivity, preferences.lastOpened[WorktreePath.key(for: item.worktree.folder)] ?? .distantPast)
    }

    func override(for item: ScannedWorktree) -> WorktreeOverride? {
        preferences.overrides[WorktreePath.key(for: item.worktree.folder)]
    }

    func resolution(for item: ScannedWorktree) -> LaunchResolution {
        LaunchResolver.resolve(folder: item.worktree.folder, detection: item.detection,
                               installed: installed, override: override(for: item),
                               repositoryIDE: repositoryEditor(for: item), fallbackIDE: preferences.fallbackIDE)
    }

    func repositoryEditor(for item: ScannedWorktree) -> IDEID? {
        preferences.editorForRepository(item.worktree)
    }

    func editorName(for item: ScannedWorktree) -> String {
        switch resolution(for: item).destination {
        case .ide(let ide): ide.displayName
        case .missingApp(let ide): "\(ide.displayName) unavailable"
        case .finder: "Finder"
        }
    }

    func editorIcon(for item: ScannedWorktree) -> NSImage? {
        switch resolution(for: item).destination {
        case .ide(let ide): editorIcons[ide]
        case .finder: finderIcon
        case .missingApp: nil
        }
    }

    func gitStatus(for item: ScannedWorktree) -> GitStatusResult? {
        gitStatusStore.results[item.id]
    }

    func refreshApplications() async {
        await workspace.refreshApplications()
        installed = Set(workspace.applications.keys)
        editorIcons = workspace.applications.mapValues { NSWorkspace.shared.icon(forFile: $0.path) }
        finderIcon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        hasApplicationCatalog = true
    }

    func contentVisibilityChanged(_ surface: String, isVisible: Bool) {
        if isVisible { visibleSurfaces.insert(surface) }
        else { visibleSurfaces.remove(surface) }
        syncState.isVisible = !visibleSurfaces.isEmpty
        gitStatusStore.setVisible(syncState.isVisible)
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
                let explicitRoots = repositoryRoots
                let snapshot = await scanner.scan(
                    codexHome: root,
                    invalidatedWorktrees: request.allProjects ? nil : request.projectIDs,
                    repositoryRoots: explicitRoots
                )
                if Task.isCancelled { syncState.invalidate(request); return }
                if codexHome != root || repositoryRoots != explicitRoots { syncState.invalidate(.full); continue }
                items = snapshot.items
                gitStatusStore.update(items)
                reconcileHighlight()
                warnings = snapshot.warnings
                repositoryStatuses = snapshot.repositoryStatuses
                lastRefreshed = Date()
            }
            gitStatusStore.invalidate(ids: request.gitStatusIDs, all: request.allGitStatuses)
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
            applicationDirectories: InstalledApplicationScanner.standardDirectories,
            repositoryRoots: repositoryRoots + repositoryStatuses.flatMap(\.unavailableWorktreeFolders),
            repositoryGitDirectories: repositoryStatuses.compactMap(\.commonGitDirectory)
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
        gitStatusStore.setVisible(syncState.isVisible)
        syncState.invalidate(.full)
        configureWatcher(force: true)
        scheduleIfVisible()
    }

    private func willSleep() {
        debounceTask?.cancel()
        gitStatusStore.setVisible(false)
        watcher.stop()
        watchedPaths = []
        isWatching = false
    }

    private func discoverySettingsChanged() {
        syncState.invalidate(.full)
        configureWatcher(force: true)
        scheduleIfVisible()
    }

    func open(_ item: ScannedWorktree, onceWith ide: IDEID? = nil) async {
        guard openingID == nil else { return }
        openingID = item.id
        defer { openingID = nil }
        await processPending(allowWhileHidden: true)
        let current = items.first { $0.id == item.id } ?? item
        do {
            let destination = ide.map {
                LaunchResolver.resolveOnce(folder: current.worktree.folder, detection: current.detection,
                                           installed: installed, ide: $0)
            } ?? resolution(for: current)
            try await workspace.open(destination)
            recordOpened(current)
            highlightedID = current.id
        } catch { errorMessage = error.localizedDescription }
    }

    func openTerminal(_ item: ScannedWorktree) async {
        guard openingID == nil else { return }
        openingID = item.id
        defer { openingID = nil }
        await processPending(allowWhileHidden: true)
        let current = items.first { $0.id == item.id } ?? item
        do {
            try await workspace.openTerminal(at: current.worktree.folder)
            recordOpened(current)
        } catch { errorMessage = error.localizedDescription }
    }

    private func recordOpened(_ item: ScannedWorktree) {
        var updated = preferences
        updated.recordOpened(item.worktree.folder, at: Date())
        save(updated)
    }

    func setOverride(_ override: WorktreeOverride?, for item: ScannedWorktree) {
        var updated = preferences
        updated.overrides[WorktreePath.key(for: item.worktree.folder)] = override
        save(updated)
    }

    func setRepositoryEditor(_ ide: IDEID?, for item: ScannedWorktree) {
        var updated = preferences
        updated.setEditor(ide, forRepository: item.worktree)
        save(updated)
    }

    func setFallback(_ ide: IDEID?) {
        var updated = preferences
        updated.fallbackIDE = ide
        save(updated)
    }

    @discardableResult
    func completeWelcome() -> Bool {
        var updated = preferences
        updated.hasCompletedWelcome = true
        return save(updated)
    }

    func setGlobalShortcut(_ shortcut: GlobalShortcut?) {
        if let shortcut, !shortcut.isValid {
            shortcutError = "Include Command, Control, or Option with a key."
            return
        }
        shortcutError = onGlobalShortcutChange?(shortcut)
        guard shortcutError == nil else { return }
        var updated = preferences
        updated.globalShortcut = shortcut
        if !save(updated) { _ = onGlobalShortcutChange?(preferences.globalShortcut) }
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

    func chooseRepository() {
        let panel = NSOpenPanel()
        panel.title = "Add repository"
        panel.message = "Choose a Git checkout or bare repository. Twig will find its local worktrees."
        panel.prompt = "Add Repository"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            Task { await addRepository(url) }
        }
    }

    func addRepository(_ url: URL) async {
        guard !isAddingRepository else { return }
        isAddingRepository = true
        defer { isAddingRepository = false }
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let result = await Task.detached(priority: .utility) {
            RepositoryDiscoverer().discover(at: canonical)
        }.value
        guard result.status.isAvailable else {
            errorMessage = result.status.message ?? "The repository is unavailable."
            return
        }
        var updated = preferences
        if !repositoryRoots.contains(where: { $0.path == canonical.path }) { updated.repositoryRoots.append(canonical.path) }
        if save(updated) {
            discoverySettingsChanged()
            await refresh()
        }
    }

    /// Removes only a discovery source. The repository and its worktrees stay on disk.
    func removeRepository(_ root: URL) {
        var updated = preferences
        updated.repositoryRoots.removeAll {
            WorktreePath.key(for: URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)) == root.path
        }
        if save(updated) {
            discoverySettingsChanged()
            Task { await refresh() }
        }
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
            shortcutError = onGlobalShortcutChange?(defaults.globalShortcut)
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
