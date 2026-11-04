import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowsManager: WindowsManager?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowsManager = WindowsManager()
        statusItem = makeStatusItem()
    }

    // LSUIElement apps have no Dock icon or main menu, so this item is the only way to quit.
    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "NotchAgents")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit NotchAgents", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        return item
    }
}
