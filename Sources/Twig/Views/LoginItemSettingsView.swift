import AppKit
import SwiftUI

struct LoginItemSettingsView: View {
    @State private var service = LoginItemService()

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle("Launch Twig at login", isOn: Binding(
                get: { service.isEnabled }, set: { service.setEnabled($0) }
            ))
            Text(service.explanation).font(.caption).foregroundStyle(.secondary)
            if service.needsApproval {
                Button("Open Login Items…") { service.openSystemSettings() }
            }
            if let error = service.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
            }
        }
        .onAppear { service.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            service.refresh()
        }
    }
}
