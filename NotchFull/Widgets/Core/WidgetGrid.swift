import Observation
import SwiftUI

/// Which widget the settings preview has selected; `nil` editor means the grid is live in the notch.
@MainActor
@Observable
final class NookEditorState {
    var selected: WidgetKind?
}

struct WidgetGrid: View {
    @Environment(\.notchStyle) private var style
    let services: AppServices
    /// When set, the grid is an editor: widgets do not react, a click selects, dragging reorders.
    var editor: NookEditorState?

    var body: some View {
        let placements = services.layout.placements
        let metrics = services.appearance.gridMetrics

        if placements.isEmpty {
            Text("No widgets enabled. Choose some in Settings.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WidgetGridMetrics.spacing) {
                    ForEach(Array(placements.enumerated()), id: \.element.id) { index, placement in
                        card(for: placement)
                            .frame(width: metrics.cardWidth(span: placement.span), height: metrics.cardHeight)
                            .overlay(alignment: .leading) {
                                // On glass, widgets sit directly on the surface and hairlines separate them.
                                if style.usesGlass && index > 0 {
                                    Rectangle()
                                        .fill(.white.opacity(0.12))
                                        .frame(width: 1, height: metrics.cardHeight * 0.6)
                                        .offset(x: -WidgetGridMetrics.spacing / 2 - 0.5)
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func card(for placement: WidgetPlacement) -> some View {
        let content = WidgetCard { widget(for: placement.kind) }

        if let editor {
            EditableWidgetCard(kind: placement.kind, editor: editor, layout: services.layout) {
                content
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private func widget(for kind: WidgetKind) -> some View {
        switch kind {
        case .music: MusicWidgetView(store: services.nowPlaying, layout: services.appearance.musicLayout)
        case .calendar: CalendarWidgetView(store: services.calendar)
        case .todo: TodoWidgetView(store: services.todos, interaction: services.interaction, pomodoro: services.pomodoro)
        case .pomodoro:
            PomodoroWidgetView(timer: services.pomodoro, settings: services.pomodoroSettings, hapticsEnabled: services.behavior.haptics)
        case .pulse: PulseWidgetView(sampler: services.pulse, settings: services.pulseSettings)
        case .notes:
            NotesWidgetView(store: services.notes, settings: services.notesSettings, interaction: services.interaction, window: services.noteWindow)
        case .clock: ClockWidgetView()
        case .agents: AgentsWidgetView()
        }
    }
}

/// A widget in the settings editor: selectable, removable and draggable onto another widget to reorder.
private struct EditableWidgetCard<Content: View>: View {
    let kind: WidgetKind
    let editor: NookEditorState
    let layout: WidgetLayoutStore
    @ViewBuilder let content: Content

    @State private var isHovered = false
    @State private var isDropTarget = false

    var body: some View {
        let isSelected = editor.selected == kind

        content
            .allowsHitTesting(false)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected || isDropTarget ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(isHovered ? 0.35 : 0)),
                        lineWidth: isSelected || isDropTarget ? 3 : 1.5
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button {
                        editor.selected = nil
                        layout.setEnabled(kind, false)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .black.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .help("Remove from Nook")
                }
            }
            .contentShape(.rect(cornerRadius: 20))
            .onTapGesture { editor.selected = kind }
            .onHover { isHovered = $0 }
            .draggable(kind.rawValue)
            .dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let dragged = WidgetKind(rawValue: raw) else { return false }
                withAnimation(.smooth) { layout.move(dragged, onto: kind) }
                editor.selected = dragged
                return true
            } isTargeted: { isDropTarget = $0 }
            .animation(.smooth(duration: 0.15), value: isSelected)
    }
}

extension EnvironmentValues {
    @Entry var notchStyle: NotchStyle = .classic
}

/// Rounded card that holds one widget; translucent on glass so the wallpaper keeps showing through.
struct WidgetCard<Content: View>: View {
    @Environment(\.notchStyle) private var style
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background, in: .rect(cornerRadius: 20, style: .continuous))
            .foregroundStyle(.white)
    }

    private var background: Color {
        switch style {
        case .classic: Color(white: 0.11)
        // On glass there is no card: the widget sits on the surface, as Apple avoids glass-on-glass layering.
        case .smokedGlass, .glass, .clearGlass: .clear
        }
    }
}
