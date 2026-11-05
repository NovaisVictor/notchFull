import SwiftUI

/// Every settings page, its place in the sidebar, its header and the words that find it in search.
/// Adding a page means adding a case here and its view in `SettingsDetail`.
enum SettingsPane: Hashable, Identifiable {
    case appearance
    case screens
    case behavior
    case nook
    case widget(WidgetKind)
    case liveActivities
    case hud
    case about

    struct Group: Identifiable {
        let title: String
        let panes: [SettingsPane]
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "General", panes: [.appearance, .screens, .behavior]),
        Group(title: "Workspaces", panes: [.nook] + WidgetKind.allCases.map(SettingsPane.widget)),
        Group(title: "Features", panes: [.liveActivities, .hud]),
        Group(title: "NotchFull", panes: [.about]),
    ]

    var id: String {
        switch self {
        case .appearance: "appearance"
        case .screens: "screens"
        case .behavior: "behavior"
        case .nook: "nook"
        case let .widget(kind): "widget.\(kind.rawValue)"
        case .liveActivities: "liveActivities"
        case .hud: "hud"
        case .about: "about"
        }
    }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .screens: "Screens"
        case .behavior: "Behavior"
        case .nook: "Nook"
        case let .widget(kind): kind.displayName
        case .liveActivities: "Live Activities"
        case .hud: "HUD"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: "paintbrush.fill"
        case .screens: "display"
        case .behavior: "hand.point.up.left.fill"
        case .nook: "square.grid.2x2.fill"
        case let .widget(kind): kind.systemImage
        case .liveActivities: "waveform"
        case .hud: "speaker.wave.2.fill"
        case .about: "info"
        }
    }

    var tint: Color {
        switch self {
        case .appearance: .indigo
        case .screens: .blue
        case .behavior: .orange
        case .nook: .teal
        case let .widget(kind):
            switch kind {
            case .music: .pink
            case .calendar: .cyan
            case .todo: .orange
            case .pomodoro: .red
            case .pulse: .green
            case .notes: .yellow
            case .clock: .gray
            case .agents: .purple
            }
        case .liveActivities: .purple
        case .hud: .mint
        case .about: .green
        }
    }

    var summary: String {
        switch self {
        case .appearance: "How the open notch looks: solid black or Liquid Glass."
        case .screens: "Which screens show the notch, what happens in full screen and on screens without a notch."
        case .behavior: "How the notch opens, what happens while you type, haptic feedback and trackpad gestures."
        case .nook: "The widgets in the open notch, their order and their width."
        case let .widget(kind): "Options for the \(kind.displayName) widget."
        case .liveActivities: "What the closed notch shows while music plays and when things happen on your Mac."
        case .hud: "Shows the volume in the notch instead of the system indicator."
        case .about: "Version, updates and source code."
        }
    }

    /// Row titles and synonyms that should find this page in search.
    var keywords: [String] {
        switch self {
        case .appearance:
            ["Notch style", "Classic", "Smoked glass", "Frosted glass", "Clear glass", "Glass level", "Liquid Glass"]
        case .screens:
            ["Displays", "Monitors", "External", "Full screen", "Handle", "Transparent handle", "Screens without a notch"]
        case .behavior:
            ["Open on hover", "Click", "Haptic feedback", "Typing", "Keep open while typing", "Gestures", "Swipe",
             "Vertical swipes", "Horizontal swipes", "Next track", "Invert"]
        case .nook:
            ["Widgets", "Reorder", "Remove", "Add", "Width", "Cells", "Restore default widgets"]
        case let .widget(kind):
            ["Width", "Cells", "Remove from Nook", "Add to Nook"] + Self.widgetKeywords(kind)
        case .liveActivities:
            ["Media", "Effect", "Audio Spectrograph", "Waves", "Vibrating Circle", "GIF", "Album corner radius", "Color effects",
             "Battery", "Low battery", "Charging", "AirPods", "Bluetooth", "Downloads", "Upcoming events", "Calendar reminder"]
        case .hud:
            ["Volume", "Mute", "Replace the volume HUD", "Indicator", "Media keys", "Accessibility", "Embedded", "Classic",
             "Brightness"]
        case .about:
            ["Version", "Updates", "GitHub", "Source code"]
        }
    }

    private static func widgetKeywords(_ kind: WidgetKind) -> [String] {
        switch kind {
        case .music: ["Player layout", "Standard", "Expanded"]
        case .todo: ["Tasks", "Show completed tasks", "Archive", "Auto-archive", "Focus time"]
        case .pomodoro: ["Timer", "Focus", "Break", "Chime", "Sound", "Rain", "Floating circle", "Satellite", "Stopwatch"]
        case .pulse: ["CPU", "RAM", "GPU", "Disk", "Battery", "Network", "Memory", "Rings", "Graphs", "Explain on hover", "Update interval"]
        case .notes: ["Notes", "Rich text", "Bold", "Code mode", "Syntax highlighting", "Export", "Scroll indicator"]
        case .calendar, .clock, .agents: []
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
