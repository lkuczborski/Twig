import AppKit
import SwiftUI

/// MenuBarExtra's window supplies a frosted backdrop underneath custom glass.
/// This bridge owns only presentation; the content and glass remain SwiftUI.
@MainActor
final class MenuBarPanelController: NSObject, NSWindowDelegate {
    private let store: TwigStore
    private var settingsWindow: NSWindow?
    private var detailsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private let statusItem: NSStatusItem
    private let panel: MenuPanel
    private var globalMouseMonitor: Any?
    private var localEventMonitor: Any?
    private var menuObservers: [NSObjectProtocol] = []
    private var selectionObservers: [NSObjectProtocol] = []
    private var trackingMenus = 0
    private var globalShortcut: GlobalShortcutService?
    private var isShuttingDown = false
#if TWIG_PREVIEW
    private var lastRecordedSelection: Bool?
#endif

    init(store: TwigStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel = MenuPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 165),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "Twig"
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: WorktreeMenuView(store: store, presentation: MenuPresentationActions(
            showSettings: { [weak self] in self?.showSettings() },
            showDetails: { [weak self] in self?.showDetails() },
            dismiss: { [weak self] in self?.dismiss() }))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                self?.resize(to: size)
            })
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Twig")
            button.image?.isTemplate = true
            // Selection is presentation state, not the transient mouse-down highlight.
            button.setButtonType(.pushOnPushOff)
            (button.cell as? NSButtonCell)?.showsStateBy = .changeBackgroundCellMask
            button.toolTip = "Twig"
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem.autosaveName = "TwigPanel"
        statusItem.isVisible = true
        statusItem.button?.setAccessibilityLabel("Twig")
        observeMenus()
        observeWindowSelection(panel)
        observeSelectionChanges([NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification], object: NSApp)
        updateStatusSelection()
        let shortcut = GlobalShortcutService { [weak self] in self?.togglePanel() }
        globalShortcut = shortcut
        store.onGlobalShortcutChange = { [weak shortcut] in shortcut?.configure($0) }
        store.shortcutError = shortcut.configure(store.preferences.globalShortcut)
    }

    @objc func showSettings() {
        dismiss()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Twig Settings"
            window.contentView = NSHostingView(rootView: TwigSettingsView(store: store, showWelcome: { [weak self] in
                self?.showWelcome()
            }))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
            observeWindowSelection(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        updateStatusSelection()
    }

    @objc func showWelcome() {
        dismiss()
        if welcomeWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 570),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Welcome to Twig"
            window.contentView = NSHostingView(rootView: WelcomeView(store: store,
                showSettings: { [weak self] in self?.showSettings() },
                finish: { [weak self] in
                    guard let self else { return }
                    // A persistence error is shown in the welcome view so a failed
                    // save never silently claims onboarding has completed.
                    guard self.store.completeWelcome() else { return }
                    self.welcomeWindow?.orderOut(nil)
                    if !self.panel.isVisible { self.togglePanel() }
                    self.updateStatusSelection()
                }))
            window.isReleasedWhenClosed = false
            window.center()
            welcomeWindow = window
            observeWindowSelection(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
        updateStatusSelection()
    }

    private func showDetails() {
        dismiss()
        if detailsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Worktree details"
            window.contentView = NSHostingView(rootView: WorktreeDetailView(store: store))
            window.contentMinSize = NSSize(width: 420, height: 350)
            window.isReleasedWhenClosed = false
            window.center()
            detailsWindow = window
            observeWindowSelection(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        detailsWindow?.makeKeyAndOrderFront(nil)
        updateStatusSelection()
    }

#if TWIG_PREVIEW
    func showPreview() {
        let preview = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 435),
                               styleMask: [.titled, .closable], backing: .buffered, defer: false)
        preview.title = "Twig Preview"
        preview.contentView = NSHostingView(rootView: WorktreeMenuView(store: store, presentation: MenuPresentationActions(
            showSettings: { [weak self] in self?.showSettings() },
            showDetails: { [weak self] in self?.showDetails() },
            dismiss: { [weak self] in
                self?.previewWindow?.orderOut(nil)
                self?.updateStatusSelection()
            })))
        preview.isReleasedWhenClosed = false
        preview.center()
        previewWindow = preview
        observeWindowSelection(preview)
        preview.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateStatusSelection()
    }
    private var previewWindow: NSWindow?
#endif

    func shutdown() {
        isShuttingDown = true
        dismiss()
        globalShortcut?.stop()
        store.onGlobalShortcutChange = nil
        menuObservers.forEach(NotificationCenter.default.removeObserver)
        menuObservers.removeAll()
        selectionObservers.forEach(NotificationCenter.default.removeObserver)
        selectionObservers.removeAll()
        statusItem.button?.state = .off
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func togglePanel() {
        if panel.isVisible { dismiss() }
        else {
            if let size = panel.contentView?.fittingSize { resize(to: size) }
            positionPanel()
            panel.makeKeyAndOrderFront(nil)
            installEventMonitors()
        }
        updateStatusSelection()
#if TWIG_PREVIEW
        PreviewEnvironment.record("panel toggled: visible=\(panel.isVisible), key=\(panel.isKeyWindow)")
#endif
    }

    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0, panel.frame.size != size else { return }
        panel.setContentSize(size)
        if panel.isVisible { positionPanel() }
    }

    private var statusButtonRect: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func positionPanel() {
        guard let button = statusButtonRect, let screen = statusItem.button?.window?.screen else { return }
        let bounds = screen.visibleFrame
        let x = min(max(button.midX - panel.frame.width / 2, bounds.minX + 6), bounds.maxX - panel.frame.width - 6)
        panel.setFrameOrigin(NSPoint(x: x, y: button.minY - panel.frame.height - 2))
    }

    private func installEventMonitors() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.statusButtonRect?.contains(NSEvent.mouseLocation) != true else { return }
                self.dismiss()
            }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.type == .keyDown {
                    if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command), self.trackingMenus == 0 {
                        switch event.charactersIgnoringModifiers {
                        case "r": Task { await self.store.refresh() }; return true
                        case ",": self.showSettings(); return true
                        case "q": NSApp.terminate(nil); return true
                        default: break
                        }
                    }
                    if event.keyCode == 53, self.trackingMenus == 0,
                       (self.panel.firstResponder as? NSTextView)?.hasMarkedText() != true {
                        self.dismiss(); return true
                    }
                } else if event.window !== self.panel, self.trackingMenus == 0,
                          self.statusButtonRect?.contains(NSEvent.mouseLocation) != true {
                    self.dismiss()
                }
                return false
            }
            return consumed ? nil : event
        }
    }

    private func observeMenus() {
        for (name, change) in [(NSMenu.didBeginTrackingNotification, 1), (NSMenu.didEndTrackingNotification, -1)] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.trackingMenus = max(0, (self?.trackingMenus ?? 0) + change) }
            })
        }
    }

    private func observeWindowSelection(_ window: NSWindow) {
        observeSelectionChanges([
            NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
            NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification
        ], object: window)
    }

    private func observeSelectionChanges(_ names: [Notification.Name], object: AnyObject) {
        for name in names {
            selectionObservers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                // In particular, willClose arrives before isVisible becomes false.
                DispatchQueue.main.async { [weak self] in self?.updateStatusSelection() }
            })
        }
    }

    private func updateStatusSelection() {
        guard !isShuttingDown else { return }
        var windows = [settingsWindow, welcomeWindow, detailsWindow].compactMap { $0 }
#if TWIG_PREVIEW
        if let previewWindow { windows.append(previewWindow) }
#endif
        let visibleWindows = windows.filter { $0.isVisible && !$0.isMiniaturized }
        // Native action menus may temporarily take key status from the visible panel.
        let selected = panel.isVisible || (NSApp.isActive && !visibleWindows.isEmpty)
        statusItem.button?.state = selected ? .on : .off
#if TWIG_PREVIEW
        if lastRecordedSelection != selected {
            lastRecordedSelection = selected
            PreviewEnvironment.record("status selection: selected=\(selected), panel=\(panel.isVisible), active=\(NSApp.isActive), windows=\(visibleWindows.map(\.title))")
        }
#endif
    }

    func windowDidResignKey(_ notification: Notification) {
        // A native action menu may temporarily own focus. Let its tracking finish.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.trackingMenus == 0, !self.panel.isKeyWindow,
                  self.statusButtonRect?.contains(NSEvent.mouseLocation) != true else { return }
            self.dismiss()
        }
    }

    private func dismiss() {
        panel.orderOut(nil)
        updateStatusSelection()
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor); globalMouseMonitor = nil }
        if let monitor = localEventMonitor { NSEvent.removeMonitor(monitor); localEventMonitor = nil }
    }
}

private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
