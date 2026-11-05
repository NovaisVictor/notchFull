import AppKit
import Observation

/// Creates one notch per enabled screen, hides it over full-screen apps per policy, and routes pointer movement.
@MainActor
final class WindowsManager {
    /// Settings like the handle width change continuously while a slider is dragged; windows are rebuilt once it settles.
    private static let rebuildDelay: Duration = .milliseconds(150)

    private let services: AppServices
    private let openSettings: () -> Void
    private var controllers: [NotchController] = []
    private var pendingRebuild: Task<Void, Never>?

    init(services: AppServices, openSettings: @escaping () -> Void) {
        self.services = services
        self.openSettings = openSettings
        rebuildControllers()
        observeScreenSettings()
        observeFullscreen()

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
        // Scroll monitoring needs no permission either; controllers ignore swipes away from the notch.
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.routeScroll(event) }
        }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.routeScroll(event) }
            return event
        }
    }

    private func routeScroll(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        for controller in controllers {
            controller.handleScroll(event, at: location)
        }
    }

    private func routeMouseLocation() {
        let location = NSEvent.mouseLocation
        for controller in controllers {
            controller.handleMouseMoved(to: location)
        }
    }

    private func rebuildControllers() {
        pendingRebuild?.cancel()
        controllers.forEach { $0.tearDown() }
        let settings = services.screens
        controllers = NSScreen.screens
            .filter { screen in screen.displayUUID.map(settings.isEnabled) ?? false }
            .map { NotchController(screen: $0, services: services, openSettings: openSettings) }
        applyFullscreenVisibility()
    }

    /// Rebuilds the windows when the enabled screens, the handle or the notch size correction change.
    private func observeScreenSettings() {
        withObservationTracking {
            let settings = services.screens
            let appearance = services.appearance
            _ = (settings.enabledDisplayUUIDs, settings.handleWidth, settings.handleHeight)
            _ = (appearance.notchWidthAdjustment, appearance.notchHeightAdjustment)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.scheduleRebuild()
                self?.observeScreenSettings()
            }
        }
    }

    private func scheduleRebuild() {
        pendingRebuild?.cancel()
        pendingRebuild = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.rebuildDelay)
            } catch {
                // A newer change scheduled its own rebuild.
                return
            }
            self?.rebuildControllers()
        }
    }

    private func observeFullscreen() {
        withObservationTracking {
            applyFullscreenVisibility()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeFullscreen() }
        }
    }

    private func applyFullscreenVisibility() {
        let covered = services.fullscreen.fullscreenDisplayUUIDs
        let policy = services.screens.fullscreenPolicy
        for controller in controllers {
            let isCovered = controller.displayUUID.map(covered.contains) ?? false
            let hides = switch policy {
            case .allScreens: false
            case .notchScreens: isCovered && !controller.geometry.hasPhysicalNotch
            case .never: isCovered
            }
            controller.setHiddenForFullscreen(hides)
        }
    }
}
