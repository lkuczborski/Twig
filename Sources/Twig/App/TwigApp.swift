import AppKit
import SwiftUI

/// AppKit owns the menu-bar lifecycle; every window's content is native SwiftUI.
@main
@MainActor
struct TwigApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = TwigAppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class TwigAppDelegate: NSObject, NSApplicationDelegate {
    private let store = TwigStore()
    private var menuController: MenuBarPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
#if TWIG_PREVIEW
        NSApp.setActivationPolicy(.regular)
#else
        NSApp.setActivationPolicy(.accessory)
#endif
        let controller = MenuBarPanelController(store: store)
        menuController = controller
        installMainMenu(controller: controller)
#if TWIG_PREVIEW
        controller.showPreview()
#endif
    }

    private func installMainMenu(controller: MenuBarPanelController) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Twig")
        let settings = NSMenuItem(title: "Settings…", action: #selector(MenuBarPanelController.showSettings), keyEquivalent: ",")
        settings.target = controller
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Twig", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"),
                                    ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
                                    ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { menuController?.shutdown() }
}
