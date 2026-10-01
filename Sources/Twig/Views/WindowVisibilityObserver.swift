import AppKit
import SwiftUI

/// SwiftUI may retain MenuBarExtra content after dismissal. Observe the actual hosting window instead.
struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> VisibilityView {
        let view = VisibilityView()
        view.onChange = onChange
        return view
    }
    func updateNSView(_ view: VisibilityView, context: Context) { view.onChange = onChange }
    static func dismantleNSView(_ view: VisibilityView, coordinator: ()) { view.disconnect() }

    final class VisibilityView: NSView {
        var onChange: ((Bool) -> Void)?
        private var lastVisible: Bool?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            NotificationCenter.default.removeObserver(self)
            super.viewWillMove(toWindow: newWindow)
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                             NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
                    NotificationCenter.default.addObserver(self, selector: #selector(windowChanged), name: name, object: window)
                }
            }
            reportVisibility()
        }
        @objc private func windowChanged(_ notification: Notification) {
            if notification.name == NSWindow.willCloseNotification { report(false) }
            else { reportVisibility() }
        }
        private func reportVisibility() {
            report(window.map { $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) } ?? false)
        }
        private func report(_ visible: Bool) {
            guard lastVisible != visible else { return }
            lastVisible = visible
            onChange?(visible)
        }
        func disconnect() {
            NotificationCenter.default.removeObserver(self)
            report(false)
            onChange = nil
        }
    }
}
