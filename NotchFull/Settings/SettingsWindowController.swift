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

private struct SettingsView: View {
    let services: AppServices
    @State private var pane: SettingsPane? = .nook
    @State private var query = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                ForEach(SettingsPane.groups) { group in
                    let panes = group.panes.filter { $0.matches(query) }
                    if !panes.isEmpty {
                        Section(group.title) {
                            ForEach(panes) { pane in
                                Label {
                                    Text(pane.title)
                                } icon: {
                                    SettingsPaneIcon(pane: pane)
                                }
                                .tag(pane)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: "Search settings")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            SettingsDetail(pane: pane ?? .nook, services: services)
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

private struct SettingsDetail: View {
    let pane: SettingsPane
    let services: AppServices

    var body: some View {
        switch pane {
        case .appearance: AppearancePage(appearance: services.appearance)
        case .screens: ScreensPage(settings: services.screens)
        case .behavior: BehaviorPage(behavior: services.behavior)
        case .nook: NookPage(services: services)
        case let .widget(kind): WidgetSettingsPage(kind: kind, services: services)
        case .liveActivities: LiveActivitiesPage(services: services)
        case .hud: HUDPage(settings: services.hudSettings, hud: services.hud)
        case .about: AboutPage()
        }
    }
}
