import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowsManager: WindowsManager?
    private var settingsWindowController: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let services = AppServices()
        windowsManager = WindowsManager(services: services) { [weak self] in self?.openSettings() }
        settingsWindowController = SettingsWindowController(services: services)
        statusItem = makeStatusItem()
    }

    @objc private func openSettings() {
        settingsWindowController?.show()
    }

    // LSUIElement apps have no Dock icon or main menu, so this item is the entry point for settings and quitting.
    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "NotchFull")

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchFull", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        return item
    }
}
