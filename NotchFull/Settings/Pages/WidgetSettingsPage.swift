import SwiftUI

/// A widget's own page in the sidebar.
struct WidgetSettingsPage: View {
    let kind: WidgetKind
    let services: AppServices

    var body: some View {
        SettingsPage(pane: .widget(kind)) {
            WidgetSettingsPanel(kind: kind, services: services)
        }
    }
}

/// Header, width and widget-specific options; shown on the widget's page and below the Nook preview.
struct WidgetSettingsPanel: View {
    let kind: WidgetKind
    let services: AppServices

    var body: some View {
        let layout = services.layout
        let isInNook = layout.enabled.contains(kind)
        let span = layout.span(for: kind)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SettingsPaneIcon(pane: .widget(kind), size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.displayName).font(.system(size: 16, weight: .semibold))
                    Text(isInNook ? "\(span) cells" : "Not in your Nook")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isInNook ? "Remove from Nook" : "Add to Nook") {
                    withAnimation(.smooth) { layout.setEnabled(kind, !isInNook) }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SettingsRow(title: "Width", info: "How many cells the widget takes in the open notch.", showsDivider: hasOptions) {
                    HStack(spacing: 10) {
                        Slider(
                            value: Binding(
                                get: { Double(span) },
                                set: { layout.setSpan(Int($0.rounded()), for: kind) }
                            ),
                            in: Double(kind.spanRange.lowerBound)...Double(kind.spanRange.upperBound),
                            step: 1
                        )
                        .frame(width: 200)
                        Text("\(span)")
                            .monospacedDigit()
                            .frame(width: 28)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: .rect(cornerRadius: 6))
                    }
                    .disabled(!isInNook)
                }

                options
            }
            .padding(16)
            .background(.background.secondary, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }

    private var hasOptions: Bool {
        kind == .music
    }

    @ViewBuilder
    private var options: some View {
        switch kind {
        case .music:
            MusicLayoutPicker(appearance: services.appearance)
                .padding(.top, 12)
        case .calendar, .todo, .clock, .agents:
            EmptyView()
        }
    }
}

private struct MusicLayoutPicker: View {
    @Bindable var appearance: AppearanceSettings

    var body: some View {
        InfoLabel(title: "Player layout", info: "How the music widget looks in the open notch.")
            .padding(.bottom, 10)

        HStack(spacing: 16) {
            ForEach(MusicWidgetLayout.allCases) { layout in
                OptionCard(
                    title: layout.displayName,
                    subtitle: layout.summary,
                    isSelected: appearance.musicLayout == layout
                ) {
                    appearance.musicLayout = layout
                } preview: {
                    MusicCardContent(
                        track: PreviewSamples.track,
                        appIcon: ScriptableMusicPlayer.spotify.applicationIcon ?? ScriptableMusicPlayer.appleMusic.applicationIcon,
                        layout: layout,
                        onCommand: { _ in }
                    )
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(width: 270, height: 96)
                    .background(Color(white: 0.11), in: .rect(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
        }
    }
}
