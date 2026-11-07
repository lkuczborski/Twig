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
    private var trackingMenus = 0
    private var globalShortcut: GlobalShortcutService?
    private var isShuttingDown = false

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
            button.toolTip = "Twig"
            if #available(macOS 27, *) {
                // AppKit owns the menu-bar selection while our custom panel is open.
                statusItem.expandedInterfaceDelegate = self
            } else {
                button.target = self
                button.action = #selector(togglePanel)
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        }
        statusItem.autosaveName = "TwigPanel"
        statusItem.isVisible = true
        statusItem.button?.setAccessibilityLabel("Twig")
        observeMenus()
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
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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
                }))
            window.isReleasedWhenClosed = false
            window.center()
            welcomeWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
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
        }
        NSApp.activate(ignoringOtherApps: true)
        detailsWindow?.makeKeyAndOrderFront(nil)
    }

#if TWIG_PREVIEW
    func showPreview() {
        let preview = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 435),
                               styleMask: [.titled, .closable], backing: .buffered, defer: false)
        preview.title = "Twig Preview"
        preview.contentView = NSHostingView(rootView: WorktreeMenuView(store: store, presentation: MenuPresentationActions(
            showSettings: { [weak self] in self?.showSettings() },
            showDetails: { [weak self] in self?.showDetails() },
            dismiss: { [weak self] in self?.previewWindow?.orderOut(nil) })))
        preview.isReleasedWhenClosed = false
        preview.center()
        preview.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewWindow = preview
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
        if #available(macOS 27, *) { statusItem.expandedInterfaceDelegate = nil }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func togglePanel() {
        if panel.isVisible { dismiss() }
        else {
            if #available(macOS 27, *) {
                // Let AppKit establish a session when supported by a programmatic
                // click. Preserve the shortcut even if it does not start one.
                statusItem.button?.performClick(nil)
            }
            if !panel.isVisible { showPanel() }
        }
#if TWIG_PREVIEW
        PreviewEnvironment.record("panel toggled: visible=\(panel.isVisible), key=\(panel.isKeyWindow)")
#endif
    }

    private func showPanel() {
        guard !isShuttingDown else { return }
        if let size = panel.contentView?.fittingSize { resize(to: size) }
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        if #unavailable(macOS 27) { statusItem.button?.highlight(true) }
        installEventMonitors()
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
        let minX = bounds.minX + 6
        let maxX = max(minX, bounds.maxX - panel.frame.width - 6)
        let leadingX = button.minX
        let trailingX = button.maxX - panel.frame.width
        // Match native menus: open from the icon's left edge when there is room,
        // otherwise align the right edges before falling back to screen bounds.
        let x: CGFloat
        if (minX...maxX).contains(leadingX) { x = leadingX }
        else if (minX...maxX).contains(trailingX) { x = trailingX }
        else { x = min(max(leadingX, minX), maxX) }
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

    func windowDidResignKey(_ notification: Notification) {
        // A native action menu may temporarily own focus. Let its tracking finish.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.trackingMenus == 0, !self.panel.isKeyWindow,
                  self.statusButtonRect?.contains(NSEvent.mouseLocation) != true else { return }
            self.dismiss()
        }
    }

    private func dismiss() {
        if #available(macOS 27, *) { statusItem.expandedInterfaceSession?.cancel() }
        hidePanel()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        if #unavailable(macOS 27) { statusItem.button?.highlight(false) }
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor); globalMouseMonitor = nil }
        if let monitor = localEventMonitor { NSEvent.removeMonitor(monitor); localEventMonitor = nil }
    }
}

@available(macOS 27, *)
extension MenuBarPanelController: @preconcurrency NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin session: NSStatusItemExpandedInterfaceSession) {
        guard !isShuttingDown else { session.cancel(); return }
        showPanel()
#if TWIG_PREVIEW
        PreviewEnvironment.record("expanded interface began: panel=\(panel.isVisible)")
#endif
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        hidePanel()
#if TWIG_PREVIEW
        PreviewEnvironment.record("expanded interface ended: panel=\(panel.isVisible)")
#endif
    }
}

private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
