import SwiftUI

struct WidgetGrid: View {
    let services: AppServices

    var body: some View {
        let kinds = services.layout.enabled

        if kinds.isEmpty {
            Text("No widgets enabled. Choose some in Settings.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WidgetGridMetrics.spacing) {
                    ForEach(kinds) { kind in
                        WidgetCard {
                            widget(for: kind)
                        }
                        .frame(width: WidgetGridMetrics.cardWidth(for: kind), height: WidgetGridMetrics.cardHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func widget(for kind: WidgetKind) -> some View {
        switch kind {
        case .music: MusicWidgetView(store: services.nowPlaying, layout: services.appearance.musicLayout)
        case .calendar: CalendarWidgetView(store: services.calendar)
        case .todo: TodoWidgetView(store: services.todos, interaction: services.interaction)
        case .clock: ClockWidgetView()
        case .agents: AgentsWidgetView()
        }
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
        case .smokedGlass: .white.opacity(0.07)
        case .glass, .clearGlass: .white.opacity(0.1)
        }
    }
}
