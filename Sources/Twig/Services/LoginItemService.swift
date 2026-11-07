import AppKit
import Observation
import ServiceManagement

/// macOS owns the login-item state, including changes made in System Settings.
@MainActor
@Observable
final class LoginItemService {
    private(set) var status = SMAppService.mainApp.status
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    var explanation: String {
        switch status {
        case .enabled: "Twig will be ready in your menu bar when you sign in."
        case .requiresApproval: "Allow Twig in Login Items to finish enabling this."
        case .notFound: "Move Twig to Applications, then try again."
        default: "Keep your worktrees close, every time you sign in."
        }
    }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = "Could not change launch at login. \(error.localizedDescription)"
        }
        refresh()
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
