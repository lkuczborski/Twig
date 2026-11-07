import AppKit
import SwiftUI
import TwigCore

struct ShortcutRecorderView: View {
    @Bindable var store: TwigStore
    @State private var recording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Show Twig")
                Spacer()
                Button(recording ? "Press shortcut…" : store.preferences.globalShortcut?.displayName ?? "Record shortcut…") {
                    recording.toggle()
                }
                .monospaced().accessibilityLabel("Record global shortcut")
                .help("Include Command, Control, or Option. Press Escape to cancel.")
                if store.preferences.globalShortcut != nil {
                    Button("Disable") { recording = false; store.setGlobalShortcut(nil) }
                }
                Button("Reset") { recording = false; store.setGlobalShortcut(.default) }
            }
            Text(recording ? "Press a key with Command, Control, or Option. Escape cancels." : "Open Twig from any app. Use ↑ ↓ to choose, Return to open, and ⇧⌘Return to switch back.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = store.shortcutError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
        .background(ShortcutCapture(recording: $recording, onShortcut: store.setGlobalShortcut).frame(width: 0, height: 0))
        .onChange(of: recording) { _, active in
            // Suspend the current registration while recording, so it can be recorded again.
            if active { _ = store.onGlobalShortcutChange?(nil) }
            else { _ = store.onGlobalShortcutChange?(store.preferences.globalShortcut) }
        }
        .onDisappear {
            recording = false
            _ = store.onGlobalShortcutChange?(store.preferences.globalShortcut)
        }
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    @Binding var recording: Bool
    let onShortcut: (GlobalShortcut) -> Void

    func makeNSView(context: Context) -> CaptureView { CaptureView() }
    func updateNSView(_ view: CaptureView, context: Context) {
        view.onShortcut = { shortcut in onShortcut(shortcut); recording = false }
        view.onCancel = { recording = false }
        view.setRecording(recording)
    }
    static func dismantleNSView(_ view: CaptureView, coordinator: ()) { view.setRecording(false) }

    final class CaptureView: NSView {
        var onShortcut: ((GlobalShortcut) -> Void)?
        var onCancel: (() -> Void)?
        private var monitor: Any?

        func setRecording(_ recording: Bool) {
            if !recording {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    let consumed = MainActor.assumeIsolated {
                        guard let self, event.window === self.window else { return false }
                        if event.keyCode == 53 { self.onCancel?(); return true }
                        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                        var modifiers: GlobalShortcut.Modifiers = []
                        if flags.contains(.command) { modifiers.insert(.command) }
                        if flags.contains(.option) { modifiers.insert(.option) }
                        if flags.contains(.control) { modifiers.insert(.control) }
                        if flags.contains(.shift) { modifiers.insert(.shift) }
                        let special: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete",
                            123: "←", 124: "→", 125: "↓", 126: "↑"]
                        let label = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
                        let shortcut = GlobalShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
                        guard shortcut.isValid else { NSSound.beep(); return true }
                        self.onShortcut?(shortcut)
                        return true
                    }
                    return consumed ? nil : event
                }
            }
        }
    }
}
