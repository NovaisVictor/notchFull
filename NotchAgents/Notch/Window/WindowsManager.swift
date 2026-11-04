import AppKit

/// Creates one notch per eligible screen and routes pointer movement to them.
@MainActor
final class WindowsManager {
    private var controllers: [NotchController] = []

    init() {
        rebuildControllers()

        // The manager lives for the whole app lifetime, so the observer and monitors are never removed.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildControllers() }
        }

        // The global monitor sees movement while other apps are active; the local one while this app is.
        // Mouse-move monitoring does not require the Accessibility permission.
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.routeMouseLocation() }
        }
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.routeMouseLocation() }
            return event
        }
    }

    private func routeMouseLocation() {
        let location = NSEvent.mouseLocation
        for controller in controllers {
            controller.handleMouseMoved(to: location)
        }
    }

    private func rebuildControllers() {
        controllers.forEach { $0.tearDown() }
        controllers = Self.eligibleScreens().map(NotchController.init(screen:))
    }

    /// Screens with a physical notch; falls back to the main screen so the app is usable on external displays.
    private static func eligibleScreens() -> [NSScreen] {
        let notched = NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }
        if !notched.isEmpty {
            return notched
        }
        return NSScreen.main.map { [$0] } ?? []
    }
}
