import AppKit

/// What the settings show about one connected display.
struct DisplayInfo: Identifiable {
    let uuid: String
    let name: String
    let isBuiltIn: Bool
    let hasNotch: Bool
    /// The display with the menu bar.
    let isPrimary: Bool
    let size: CGSize
    let wallpaperURL: URL?

    var id: String { uuid }

    var traits: String {
        var parts = [isBuiltIn ? "Built-in" : "External"]
        if hasNotch { parts.append("Notch") }
        if isPrimary { parts.append("Main") }
        return parts.joined(separator: " · ")
    }

    @MainActor
    static func connected() -> [DisplayInfo] {
        let primary = NSScreen.screens.first
        return NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID, let displayID = screen.displayID else { return nil }
            return DisplayInfo(
                uuid: uuid,
                name: screen.localizedName,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                hasNotch: screen.hasPhysicalNotch,
                isPrimary: screen == primary,
                size: screen.frame.size,
                wallpaperURL: NSWorkspace.shared.desktopImageURL(for: screen)
            )
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// Stable across reboots and reconnections, unlike `displayID`, so it is what settings persist.
    var displayUUID: String? {
        guard let displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    var hasPhysicalNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// Height of the menu bar on this screen, or the system's standard height when it is hidden.
    var menuBarHeight: CGFloat {
        let height = frame.maxY - visibleFrame.maxY
        return height > 0 ? height : NSStatusBar.system.thickness
    }
}
