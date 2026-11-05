import SwiftUI

/// Every settings page, its place in the sidebar, its header and the words that find it in search.
/// Adding a page means adding a case here and its view in `SettingsDetail`.
enum SettingsPane: Hashable, Identifiable {
    case appearance
    case nook
    case widget(WidgetKind)
    case liveActivities
    case about

    struct Group: Identifiable {
        let title: String
        let panes: [SettingsPane]
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "General", panes: [.appearance]),
        Group(title: "Workspaces", panes: [.nook] + WidgetKind.allCases.map(SettingsPane.widget)),
        Group(title: "Features", panes: [.liveActivities]),
        Group(title: "NotchFull", panes: [.about]),
    ]

    var id: String {
        switch self {
        case .appearance: "appearance"
        case .nook: "nook"
        case let .widget(kind): "widget.\(kind.rawValue)"
        case .liveActivities: "liveActivities"
        case .about: "about"
        }
    }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .nook: "Nook"
        case let .widget(kind): kind.displayName
        case .liveActivities: "Live Activities"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: "paintbrush.fill"
        case .nook: "square.grid.2x2.fill"
        case let .widget(kind): kind.systemImage
        case .liveActivities: "waveform"
        case .about: "info"
        }
    }

    var tint: Color {
        switch self {
        case .appearance: .indigo
        case .nook: .teal
        case let .widget(kind):
            switch kind {
            case .music: .pink
            case .calendar: .red
            case .todo: .orange
            case .clock: .gray
            case .agents: .purple
            }
        case .liveActivities: .purple
        case .about: .green
        }
    }

    var summary: String {
        switch self {
        case .appearance: "How the open notch looks: solid black or Liquid Glass."
        case .nook: "The widgets in the open notch, their order and their width."
        case let .widget(kind): "Options for the \(kind.displayName) widget."
        case .liveActivities: "What the closed notch shows while music plays and when things happen on your Mac."
        case .about: "Version, updates and source code."
        }
    }

    /// Row titles and synonyms that should find this page in search.
    var keywords: [String] {
        switch self {
        case .appearance:
            ["Notch style", "Classic", "Smoked glass", "Frosted glass", "Clear glass", "Glass level", "Liquid Glass"]
        case .nook:
            ["Widgets", "Reorder", "Remove", "Add", "Width", "Cells", "Restore default widgets"]
        case let .widget(kind):
            ["Width", "Cells", "Remove from Nook", "Add to Nook"] + (kind == .music ? ["Player layout", "Standard", "Expanded"] : [])
        case .liveActivities:
            ["Media", "Effect", "Audio Spectrograph", "Waves", "Vibrating Circle", "GIF", "Album corner radius", "Color effects",
             "Battery", "Low battery", "Charging", "AirPods", "Bluetooth", "Downloads", "Upcoming events", "Calendar reminder"]
        case .about:
            ["Version", "Updates", "GitHub", "Source code"]
        }
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return ([title] + keywords).contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

/// The colored rounded icon used in the sidebar and in page headers.
struct SettingsPaneIcon: View {
    let pane: SettingsPane
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: pane.systemImage)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(pane.tint.gradient, in: .rect(cornerRadius: size * 0.27, style: .continuous))
    }
}
