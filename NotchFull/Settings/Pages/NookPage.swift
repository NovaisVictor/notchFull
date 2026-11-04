import SwiftUI

/// The open notch ("Nook"): live preview, which widgets it shows and in what order, and per-widget options.
struct NookPage: View {
    let services: AppServices

    var body: some View {
        SettingsPage(title: "Nook") {
            SettingsSection(title: "Your Nook", info: "A live preview of the open notch with your widgets.") {
                LiveNookPreview(services: services)
            }

            SettingsSection(title: "Widgets", info: "Turn widgets on or off and drag to reorder them.") {
                WidgetLayoutEditor(layout: services.layout)
            }

            SettingsSection(title: "Media player", systemImage: "music.note") {
                MusicLayoutPicker(appearance: services.appearance)
            }
        }
    }
}

/// The real widget grid, scaled down to fit the settings page.
private struct LiveNookPreview: View {
    let services: AppServices

    var body: some View {
        let closedHeight = PreviewMetrics.closedSize.height
        let openSize = WidgetGridMetrics.openSize(for: services.layout.enabled, closedHeight: closedHeight)

        GeometryReader { proxy in
            let scale = min(1, proxy.size.width / (openSize.width + 40))
            OpenNotchPreview(style: services.appearance.notchStyle, glassLevel: services.appearance.glassLevel, size: openSize) {
                WidgetGrid(services: services)
            }
            .frame(width: openSize.width + 40, height: openSize.height + 24)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width, height: (openSize.height + 24) * scale, alignment: .topLeading)
        }
        .frame(height: (openSize.height + 24) * 0.75)
        .animation(.smooth, value: services.layout.enabled)
    }
}

private struct WidgetLayoutEditor: View {
    let layout: WidgetLayoutStore

    var body: some View {
        List {
            ForEach(layout.enabled) { kind in
                row(for: kind, isEnabled: true)
            }
            .onMove { layout.move(fromOffsets: $0, toOffset: $1) }

            ForEach(layout.disabled) { kind in
                row(for: kind, isEnabled: false)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(height: CGFloat(WidgetKind.allCases.count) * 36)

        Label("Drag enabled widgets to reorder", systemImage: "hand.draw")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    private func row(for kind: WidgetKind, isEnabled: Bool) -> some View {
        HStack {
            Image(systemName: kind.systemImage)
                .frame(width: 20)
                .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(kind.displayName)
            Text("\(kind.span) cells")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: Binding(get: { isEnabled }, set: { layout.setEnabled(kind, $0) }))
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 2)
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
