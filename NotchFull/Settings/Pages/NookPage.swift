import SwiftUI

/// The open notch ("Nook"): an editable live preview, widgets to add, and the selected widget's options.
struct NookPage: View {
    let services: AppServices
    @State private var editor = NookEditorState()

    var body: some View {
        let layout = services.layout

        SettingsPage(pane: .nook) {
            SettingsSection(
                title: "Your Nook",
                info: "The open notch with your widgets. Click a widget to edit it; drag it onto another to reorder.",
                accessory: {
                    Button("Restore default widgets") {
                        editor.selected = nil
                        withAnimation(.smooth) { layout.restoreDefaults() }
                    }
                    .controlSize(.small)
                }
            ) {
                LiveNookPreview(services: services, editor: editor)

                HStack {
                    Label("Drag to reorder · Click to edit", systemImage: "hand.draw")
                    Spacer()
                    Text("\(layout.placements.count) widgets · \(layout.totalCells) cells")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)

                if let error = layout.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }
            }

            if !layout.disabled.isEmpty {
                SettingsSection(title: "Add widgets") {
                    FlowChips(kinds: layout.disabled) { kind in
                        withAnimation(.smooth) { layout.setEnabled(kind, true) }
                        editor.selected = kind
                    }
                }
            }

            if let selected = editor.selected, layout.enabled.contains(selected) {
                WidgetSettingsPanel(kind: selected, services: services)
                    .id(selected)
            }
        }
    }
}

/// The real widget grid in edit mode, scaled down to fit the settings page.
private struct LiveNookPreview: View {
    let services: AppServices
    let editor: NookEditorState

    var body: some View {
        let closedHeight = PreviewMetrics.closedSize.height
        let openSize = services.appearance.gridMetrics.openSize(for: services.layout.placements.map(\.span), closedHeight: closedHeight)

        GeometryReader { proxy in
            let scale = min(1, proxy.size.width / (openSize.width + 40))
            OpenNotchPreview(style: services.appearance.notchStyle, glassLevel: services.appearance.glassLevel, size: openSize) {
                WidgetGrid(services: services, editor: editor)
            }
            .frame(width: openSize.width + 40, height: openSize.height + 24)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width, height: (openSize.height + 24) * scale, alignment: .topLeading)
        }
        .frame(height: (openSize.height + 24) * 0.75)
        .animation(.smooth, value: services.layout.placements)
    }
}

/// Widgets not in the Nook, as buttons that add them.
private struct FlowChips: View {
    let kinds: [WidgetKind]
    let onAdd: (WidgetKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(kinds) { kind in
                Button {
                    onAdd(kind)
                } label: {
                    Label(kind.displayName, systemImage: "plus")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
