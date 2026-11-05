/// Closed catalog of widgets the notch can show. Raw values are persisted, so never rename a case;
/// stored values of removed cases are dropped when the layout loads.
enum WidgetKind: String, CaseIterable, Identifiable {
    case music
    case calendar
    case todo
    case pomodoro
    case clock
    case agents

    static let defaultLayout: [WidgetKind] = [.music, .calendar, .todo]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .music: "Music"
        case .calendar: "Calendar"
        case .todo: "To-dos"
        case .pomodoro: "Pomodoro"
        case .clock: "Clock"
        case .agents: "Agents"
        }
    }

    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .calendar: "calendar"
        case .todo: "checklist"
        case .pomodoro: "timer"
        case .clock: "clock"
        case .agents: "sparkles"
        }
    }

    /// Width in grid cells when the widget is added.
    var defaultSpan: Int {
        switch self {
        case .music, .calendar, .todo, .agents: 5
        case .pomodoro: 6
        case .clock: 3
        }
    }

    /// Widths the widget's content can lay out in.
    var spanRange: ClosedRange<Int> {
        switch self {
        case .music: 4...7
        case .calendar: 4...8
        case .todo: 3...8
        case .pomodoro: 5...8
        case .clock: 2...4
        case .agents: 4...8
        }
    }
}

/// A widget in the Nook and the width the user chose for it.
struct WidgetPlacement: Equatable, Identifiable {
    let kind: WidgetKind
    var span: Int

    var id: WidgetKind { kind }
}
