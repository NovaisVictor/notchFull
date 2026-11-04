import AppKit
import SwiftUI

/// Owns the settings window. The SwiftUI `Settings` scene cannot be opened from an AppKit menu in an LSUIElement app.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(services: AppServices) {
        window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(services: services)))
        window.title = "NotchFull"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 920, height: 700))
        window.contentMinSize = CGSize(width: 760, height: 520)
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case appearance
    case nook
    case liveActivities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .nook: "Nook"
        case .liveActivities: "Live Activities"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: "paintbrush.fill"
        case .nook: "square.grid.2x2.fill"
        case .liveActivities: "waveform"
        }
    }
}

private struct SettingsView: View {
    let services: AppServices
    @State private var pane: SettingsPane = .nook

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch pane {
            case .appearance: AppearancePage(appearance: services.appearance)
            case .nook: NookPage(services: services)
            case .liveActivities: LiveActivitiesPage(services: services)
            }
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}
