import AppKit
import SwiftUI

@main
struct TwigApp: App {
    @NSApplicationDelegateAdaptor(TwigAppDelegate.self) private var delegate
    @State private var store = TwigStore()

    var body: some Scene {
#if TWIG_PREVIEW
        // Compile-time development surface for inspecting the same menu content.
        WindowGroup("Twig Preview") {
            WorktreeMenuView(store: store)
        }
        .windowResizability(.contentSize)
#else
        MenuBarExtra("Twig", systemImage: "arrow.triangle.branch") {
            WorktreeMenuView(store: store)
        }
        .menuBarExtraStyle(.window)
#endif

        Window("Worktree details", id: "details") {
            WorktreeDetailView(store: store)
        }
        .defaultSize(width: 580, height: 520)
        .windowResizability(.contentMinSize)

        Settings {
            TwigSettingsView(store: store)
        }
    }
}

final class TwigAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
#if TWIG_PREVIEW
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
#else
        // Twig deliberately lives only in the menu bar, without a Dock icon.
        NSApp.setActivationPolicy(.accessory)
#endif
    }
}
