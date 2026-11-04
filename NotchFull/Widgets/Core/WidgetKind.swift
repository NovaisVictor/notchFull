/// Closed catalog of widgets the notch can show. Raw values are persisted, so never rename a case;
/// stored values of removed cases are dropped when the layout loads.
enum WidgetKind: String, CaseIterable, Identifiable {
    case music
    case calendar
    case todo
    case clock
    case agents

    static let defaultLayout: [WidgetKind] = [.music, .calendar, .todo]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .music: "Music"
        case .calendar: "Calendar"
        case .todo: "To-dos"
        case .clock: "Clock"
        case .agents: "Agents"
        }
    }

    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .calendar: "calendar"
        case .todo: "checklist"
        case .clock: "clock"
        case .agents: "sparkles"
        }
    }

    /// Width in grid columns.
    var span: Int {
        switch self {
        case .music, .calendar, .todo, .agents: 2
        case .clock: 1
        }
    }
}
