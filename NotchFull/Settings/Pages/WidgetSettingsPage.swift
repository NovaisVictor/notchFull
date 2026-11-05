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
        kind == .music || kind == .todo || kind == .pomodoro
    }

    @ViewBuilder
    private var options: some View {
        switch kind {
        case .music:
            MusicLayoutPicker(appearance: services.appearance)
                .padding(.top, 12)
        case .todo:
            TodoOptions(settings: services.todoSettings, store: services.todos)
        case .pomodoro:
            PomodoroOptions(settings: services.pomodoroSettings, rain: services.rain)
        case .calendar, .clock, .agents:
            EmptyView()
        }
    }
}

private struct PomodoroOptions: View {
    @Bindable var settings: PomodoroSettings
    let rain: RainAmbience

    var body: some View {
        SettingsRow(title: "Focus", info: "Length of a focus session. The ruler in the widget changes it too.") {
            minutesStepper($settings.focusMinutes, range: PomodoroSettings.focusRange)
        }
        SettingsRow(title: "Break", info: "Starts automatically when a focus session ends.") {
            minutesStepper($settings.breakMinutes, range: PomodoroSettings.breakRange)
        }
        SettingsRow(title: "Show in the notch while running") {
            Toggle("", isOn: $settings.showsInNotch).labelsHidden().toggleStyle(.switch)
        }
        SettingsRow(title: "Floating circle", info: "A small circle next to the notch with the time left, while the timer runs.") {
            Toggle("", isOn: $settings.showsSatellite).labelsHidden().toggleStyle(.switch)
        }
        SettingsRow(title: "Chime") {
            HStack {
                Picker("", selection: $settings.chimeSound) {
                    ForEach(PomodoroSettings.chimeSounds, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 140)
                Button("Play", systemImage: "play.fill") { settings.playChime() }
                    .labelStyle(.iconOnly)
            }
        }
        SettingsRow(title: "Play chime") {
            Toggle("", isOn: $settings.playsChime).labelsHidden().toggleStyle(.switch)
        }
        SettingsRow(title: "Rain during breaks", info: "Soft synthesized rain while a break runs.", showsDivider: rain.lastError != nil) {
            Toggle("", isOn: $settings.rainDuringBreaks).labelsHidden().toggleStyle(.switch)
        }
        if let error = rain.lastError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.top, 8)
        }
    }

    private func minutesStepper(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            Text("\(value.wrappedValue) min").monospacedDigit()
        }
    }
}

private struct TodoOptions: View {
    @Bindable var settings: TodoSettings
    let store: TodoStore

    var body: some View {
        SettingsRow(title: "Show completed tasks") {
            Toggle("", isOn: $settings.showsCompleted).labelsHidden().toggleStyle(.switch)
        }
        SettingsRow(
            title: "Archive completed tasks automatically",
            info: "Completed tasks older than this leave the list and move to the archive below.",
            showsDivider: true
        ) {
            Stepper(value: $settings.autoArchiveDays, in: TodoSettings.autoArchiveRange) {
                Text(settings.autoArchiveDays == 0 ? "Never" : "After \(settings.autoArchiveDays) \(settings.autoArchiveDays == 1 ? "day" : "days")")
                    .monospacedDigit()
            }
        }
        .onChange(of: settings.autoArchiveDays) { store.archiveExpired() }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                InfoLabel(title: "Archive", info: "Archived tasks are kept here until you delete them.")
                Spacer()
                Button("Archive completed now") { store.archiveCompletedNow() }
                    .controlSize(.small)
                Button("Delete archive", role: .destructive) { store.deleteArchived() }
                    .controlSize(.small)
                    .disabled(store.archivedItems.isEmpty)
            }
            if store.archivedItems.isEmpty {
                Text("No archived tasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.archivedItems) { item in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.orange)
                        Text(item.title).strikethrough().foregroundStyle(.secondary)
                        Spacer()
                        if let archivedAt = item.archivedAt {
                            Text(archivedAt, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Button("Restore") { store.restore(item.id) }
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(.top, 12)
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
