import SwiftUI

/// The volume and brightness HUD: whether each replaces the system one, the Accessibility permission they share and
/// the style.
struct HUDPage: View {
    @Bindable var settings: HUDSettings
    let hud: NotchHUD

    var body: some View {
        SettingsPage(pane: .hud) {
            VolumeSection(settings: settings, hud: hud)
            BrightnessSection(settings: settings, hud: hud)
            AccessibilitySection(keyTap: hud.keyTap)
            StyleSection(settings: settings)
        }
    }
}

// MARK: - Volume

private struct VolumeSection: View {
    @Bindable var settings: HUDSettings
    let hud: NotchHUD

    var body: some View {
        SettingsSection(title: "Volume", systemImage: "speaker.wave.2.fill", accessory: {
            Button("Show in notch", systemImage: "play.circle") {
                hud.show(PreviewSamples.volume)
            }
            .controlSize(.small)
        }) {
            HUDPreview(state: PreviewSamples.volume, style: settings.style)
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 12)

            SettingsRow(
                title: "Replace the volume HUD",
                info: "Volume up, volume down and mute. Option-Shift changes the volume in fine steps.",
                showsDivider: false
            ) {
                Toggle("", isOn: $settings.replacesVolume).labelsHidden().toggleStyle(.switch)
            }
            .onChange(of: settings.replacesVolume) { _, replaces in
                if replaces, !hud.keyTap.isTrusted {
                    hud.keyTap.requestAccess()
                }
            }

            IssueLabels(issues: hud.volumeIssues)
        }
    }
}

// MARK: - Brightness

private struct BrightnessSection: View {
    @Bindable var settings: HUDSettings
    let hud: NotchHUD

    var body: some View {
        SettingsSection(title: "Brightness", systemImage: "sun.max.fill", accessory: {
            Button("Show in notch", systemImage: "play.circle") {
                hud.show(PreviewSamples.brightness)
            }
            .controlSize(.small)
        }) {
            HUDPreview(state: PreviewSamples.brightness, style: settings.style)
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 12)

            SettingsRow(
                title: "Replace the brightness HUD",
                info: "Brightness up and down for the built-in display. Option-Shift changes the brightness in fine steps. External displays keep the system indicator."
            ) {
                Toggle("", isOn: $settings.replacesBrightness).labelsHidden().toggleStyle(.switch)
            }
            .onChange(of: settings.replacesBrightness) { _, replaces in
                if replaces, !hud.keyTap.isTrusted {
                    hud.keyTap.requestAccess()
                }
            }

            SettingsRow(
                title: "Display control",
                info: "macOS has no public API for the built-in display's brightness, so NotchFull uses Apple's private DisplayServices framework. If it is missing or fails, the brightness keys keep the system indicator.",
                showsDivider: false
            ) {
                if hud.brightness.unavailableReason == nil {
                    Label("Available", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Unavailable", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            if let reason = hud.brightness.unavailableReason {
                Label(reason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            IssueLabels(issues: hud.brightnessIssues)
        }
    }
}

// MARK: - Accessibility

private struct AccessibilitySection: View {
    let keyTap: MediaKeyTap

    var body: some View {
        SettingsSection(title: "Permission", systemImage: "hand.raised.fill") {
            SettingsRow(
                title: "Accessibility",
                info: "NotchFull reads the volume and brightness keys before macOS so the system indicator stays hidden. Without this permission the keys work as usual.",
                showsDivider: false
            ) {
                if keyTap.isTrusted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Button("Request Access") { keyTap.requestAccess() }
                        Button("Open System Settings") { keyTap.openAccessibilitySettings() }
                    }
                }
            }

            if let error = keyTap.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
    }
}

/// The last failure and pass-through reason for one kind of key.
private struct IssueLabels: View {
    let issues: NotchHUD.Issues

    var body: some View {
        if let error = issues.error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.top, 8)
        }
        if let reason = issues.passThroughReason {
            Label(reason, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Style

private struct StyleSection: View {
    @Bindable var settings: HUDSettings

    var body: some View {
        SettingsSection(title: "Style", systemImage: "rectangle.topthird.inset.filled") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(HUDStyle.allCases) { style in
                    OptionCard(title: style.displayName, subtitle: subtitle(style), isSelected: settings.style == style) {
                        settings.style = style
                    } preview: {
                        HUDPreview(state: PreviewSamples.volume, style: style, scale: 0.7)
                    }
                }
            }
        }
    }

    private func subtitle(_ style: HUDStyle) -> String {
        switch style {
        case .embedded: "Stays in the notch line."
        case .classic: "Grows below the notch."
        }
    }
}

/// The closed notch showing the HUD in a style, on a wallpaper strip; scaled down to fit option cards.
private struct HUDPreview: View {
    let state: HUDState
    let style: HUDStyle
    var scale: CGFloat = 1

    var body: some View {
        let closedSize = PreviewMetrics.closedSize
        let activity = LiveActivityCenter.Activity.hud(state, style: style)
        let side = activity.sideWidth(closedHeight: closedSize.height)
        let below = activity.heightBelowNotch

        // An overlay does not take part in layout, so the full-width notch never widens the card it sits in.
        WallpaperBackdrop()
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    ClosedNotchSlots(closedSize: closedSize, sideWidth: side) {
                        if style == .embedded {
                            HUDEmbeddedLeadingView(state: state)
                        }
                    } trailing: {
                        if style == .embedded {
                            HUDEmbeddedTrailingView(state: state)
                        }
                    }
                    if below > 0 {
                        HUDClassicView(state: state)
                            .frame(height: below, alignment: .top)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(width: closedSize.width + side * 2)
                .background {
                    NotchShape(topRadius: 6, bottomRadius: below > 0 ? 16 : 10)
                        .fill(.black)
                        .padding(.horizontal, -6)
                }
                .scaleEffect(scale, anchor: .top)
            }
    }
}

extension PreviewSamples {
    static let volume = HUDState.volume(level: 0.68, isMuted: false, deviceName: nil)
    static let brightness = HUDState.brightness(level: 0.68)
}
