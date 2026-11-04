import SwiftUI

/// Scrollable page with a large title, used by every settings pane.
struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                content
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Titled group of controls on a rounded surface.
struct SettingsSection<Content: View, Accessory: View>: View {
    let title: String
    var systemImage: String?
    var info: String?
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.tint, in: .rect(cornerRadius: 8, style: .continuous))
                }
                InfoLabel(title: title, info: info)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                accessory
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }
}

extension SettingsSection where Accessory == EmptyView {
    init(title: String, systemImage: String? = nil, info: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, info: info, accessory: { EmptyView() }, content: content)
    }
}

/// One labeled control line; rows are separated by hairlines.
struct SettingsRow<Control: View>: View {
    let title: String
    var info: String?
    var showsDivider = true
    @ViewBuilder let control: Control

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InfoLabel(title: title, info: info)
                Spacer(minLength: 16)
                control
            }
            .padding(.vertical, 10)
            if showsDivider {
                Divider()
            }
        }
    }
}

struct InfoLabel: View {
    let title: String
    let info: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let info {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .help(info)
            }
        }
    }
}

/// Selectable card with a visual preview above its title, like a radio button you can see.
struct OptionCard<Preview: View>: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var previewHeight: CGFloat = 110
    let action: () -> Void
    @ViewBuilder let preview: Preview

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview
                    .frame(maxWidth: .infinity)
                    .frame(height: previewHeight)
                    .background(Color(white: 0.07), in: .rect(cornerRadius: 12, style: .continuous))
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.08)), lineWidth: isSelected ? 2.5 : 1)
                    }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .font(.system(size: 15))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        if let subtitle {
                            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}
