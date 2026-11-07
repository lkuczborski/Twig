import AppKit
import SwiftUI

/// Handles list navigation before the search field's editor consumes arrow keys on macOS 14+.
struct MenuKeyboardHandler: NSViewRepresentable {
    let onMove: (Int) -> Void
    let onOpen: () -> Void
    let onPrevious: () -> Void
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> KeyView { KeyView() }
    func updateNSView(_ view: KeyView, context: Context) {
        view.onMove = onMove
        view.onOpen = onOpen
        view.onPrevious = onPrevious
        view.onDismiss = onDismiss
    }
    static func dismantleNSView(_ view: KeyView, coordinator: ()) { view.disconnect() }

    final class KeyView: NSView {
        var onMove: ((Int) -> Void)?
        var onOpen: (() -> Void)?
        var onPrevious: (() -> Void)?
        var onDismiss: (() -> Void)?
        private var monitor: Any?
        private var trackingMenus = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            disconnect()
            guard window != nil else { return }
            NotificationCenter.default.addObserver(self, selector: #selector(menuBegan), name: NSMenu.didBeginTrackingNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(menuEnded), name: NSMenu.didEndTrackingNotification, object: nil)
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let consumed = MainActor.assumeIsolated {
                    guard let self, event.window === self.window, self.trackingMenus == 0 else { return false }
                    // Let input methods finish their composition before interpreting navigation.
                    if let editor = self.window?.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
                    let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                    if flags == [.command, .shift], event.keyCode == 36 {
                        self.onPrevious?(); return true
                    }
                    guard flags.isEmpty else { return false }
                    switch event.keyCode {
                    case 125: self.onMove?(1)
                    case 126: self.onMove?(-1)
                    case 36, 76: self.onOpen?()
                    case 53: self.onDismiss?()
                    default: return false
                    }
                    return true
                }
                return consumed ? nil : event
            }
        }
        @objc private func menuBegan() { trackingMenus += 1 }
        @objc private func menuEnded() { trackingMenus = max(0, trackingMenus - 1) }
        func disconnect() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            trackingMenus = 0
            NotificationCenter.default.removeObserver(self)
        }
    }
}
