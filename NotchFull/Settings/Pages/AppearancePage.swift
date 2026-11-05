import SwiftUI

struct AppearancePage: View {
    @Bindable var appearance: AppearanceSettings

    var body: some View {
        SettingsPage(pane: .appearance) {
            SettingsSection(
                title: "Notch style",
                info: "Applies to the open notch. Closed, it stays black to blend with the camera housing."
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 18) {
                    ForEach(NotchStyle.allCases) { style in
                        OptionCard(
                            title: style.displayName,
                            subtitle: style.summary,
                            isSelected: appearance.notchStyle == style,
                            previewHeight: 130
                        ) {
                            appearance.notchStyle = style
                        } preview: {
                            StylePreview(style: style, glassLevel: appearance.glassLevel)
                        }
                    }
                }
                .padding(.bottom, 14)

                SettingsRow(
                    title: "Glass level",
                    info: "How dark smoked glass is. Lower lets more of your wallpaper glow through.",
                    showsDivider: false
                ) {
                    HStack(spacing: 10) {
                        Text("Clear").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $appearance.glassLevel, in: AppearanceSettings.glassLevelRange)
                            .frame(width: 200)
                        Text("Dark").font(.caption).foregroundStyle(.secondary)
                        Button("Default") { appearance.glassLevel = AppearanceSettings.defaultGlassLevel }
                            .controlSize(.small)
                            .disabled(appearance.glassLevel == AppearanceSettings.defaultGlassLevel)
                    }
                }
                .disabled(appearance.notchStyle != .smokedGlass)
            }

            SettingsSection(title: "Size", info: "The island is the open notch. The notch correction adjusts the measured size of the closed notch.") {
                Grid(horizontalSpacing: 28, verticalSpacing: 18) {
                    GridRow {
                        SizeSlider(
                            title: "Island width",
                            value: $appearance.cellWidth,
                            range: AppearanceSettings.cellWidthRange,
                            defaultValue: AppearanceSettings.defaultCellWidth,
                            labels: ("Compact", "Wide")
                        )
                        SizeSlider(
                            title: "Island height",
                            value: $appearance.cardHeight,
                            range: AppearanceSettings.cardHeightRange,
                            defaultValue: AppearanceSettings.defaultCardHeight,
                            labels: ("Compact", "Tall")
                        )
                    }
                    GridRow {
                        SizeSlider(
                            title: "Notch width",
                            value: $appearance.notchWidthAdjustment,
                            range: AppearanceSettings.notchWidthAdjustmentRange,
                            defaultValue: 0,
                            labels: ("Narrower", "Wider")
                        )
                        SizeSlider(
                            title: "Notch height",
                            value: $appearance.notchHeightAdjustment,
                            range: AppearanceSettings.notchHeightAdjustmentRange,
                            defaultValue: 0,
                            labels: ("Shorter", "Taller")
                        )
                    }
                }
            }

            SettingsSection(title: "Animation") {
                SettingsRow(title: "Speed", info: "How long the notch takes to open and close.") {
                    HStack(spacing: 10) {
                        Text("Fast").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $appearance.animationDuration, in: AppearanceSettings.animationDurationRange)
                            .frame(width: 200)
                        Text("Slow").font(.caption).foregroundStyle(.secondary)
                        Button("Default") { appearance.animationDuration = AppearanceSettings.defaultAnimationDuration }
                            .controlSize(.small)
                            .disabled(appearance.animationDuration == AppearanceSettings.defaultAnimationDuration)
                    }
                }
                SettingsRow(title: "Bounce", info: "A springy overshoot when the notch opens and closes.", showsDivider: false) {
                    Toggle("", isOn: $appearance.animationBounces).labelsHidden().toggleStyle(.switch)
                }
            }
        }
    }
}

/// A labeled slider with its own reset button, laid out in a two-column grid.
private struct SizeSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    let labels: (low: String, high: String)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Default") { value = defaultValue }
                    .controlSize(.small)
                    .disabled(value == defaultValue)
            }
            Slider(value: $value, in: range, step: 1)
            HStack {
                Text(labels.low)
                Spacer()
                Text(labels.high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A wide strip with the open notch hanging from the top, like the real screen.
private struct StylePreview: View {
    let style: NotchStyle
    let glassLevel: Double

    var body: some View {
        ZStack(alignment: .top) {
            WallpaperBackdrop()
            NookSkeleton()
                .padding(.top, 14)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(width: 190, height: 92)
                .background {
                    NotchSurface(style: style, glassLevel: glassLevel, topRadius: 9, bottomRadius: 20, source: .withinWindow)
                }
                .environment(\.notchStyle, style)
        }
    }
}
