import AppKit
import Observation

/// Tracks which displays currently show a full-screen app.
@MainActor
@Observable
final class FullscreenMonitor {
    /// UUIDs of displays covered by a full-screen window.
    private(set) var fullscreenDisplayUUIDs: Set<String> = []

    /// Space switches animate; checking again after the animation catches the final state.
    private static let settleDelay: Duration = .milliseconds(700)

    @ObservationIgnored private var delayedCheck: Task<Void, Never>?

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        // The monitor lives for the app's lifetime, so the observers are never removed.
        for name in names {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleCheck() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        }
        check()
    }

    private func scheduleCheck() {
        check()
        delayedCheck?.cancel()
        delayedCheck = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.settleDelay)
            } catch {
                // A newer change scheduled its own check.
                return
            }
            self?.check()
        }
    }

    private func check() {
        let covered = Self.coveredDisplayUUIDs()
        if covered != fullscreenDisplayUUIDs {
            fullscreenDisplayUUIDs = covered
        }
    }

    /// A display counts as full screen when an ordinary window of another app covers its whole frame.
    /// Only window bounds are read, which needs no Screen Recording permission (titles would).
    private static func coveredDisplayUUIDs() -> Set<String> {
        guard let primary = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let windowFrames: [CGRect] = windows.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  (window[kCGWindowOwnerPID as String] as? pid_t) != ownPID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            return frame
        }

        var covered = Set<String>()
        for screen in NSScreen.screens {
            guard let uuid = screen.displayUUID else { continue }
            // Window bounds use top-left-origin coordinates anchored to the primary display.
            let screenFrame = CGRect(
                x: screen.frame.minX,
                y: primary.frame.maxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            if windowFrames.contains(where: { Self.approximatelyEqual($0, screenFrame) }) {
                covered.insert(uuid)
            }
        }
        return covered
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 1 && abs(lhs.minY - rhs.minY) <= 1
            && abs(lhs.width - rhs.width) <= 1 && abs(lhs.height - rhs.height) <= 1
    }
}
