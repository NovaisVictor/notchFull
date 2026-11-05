import SwiftUI

struct NotesWidgetView: View {
    let store: NoteStore
    let settings: NotesSettings
    let interaction: NotchInteraction
    let window: NoteWindowController

    var body: some View {
        NoteEditorPane(store: store, settings: settings, onExpand: { window.show() }) { focused in
            interaction.isEditingText = focused
        }
    }
}

/// The current note with its formatting toolbar; shared by the notch widget and the note window.
struct NoteEditorPane: View {
    let store: NoteStore
    let settings: NotesSettings
    var textInset = CGSize(width: 0, height: 2)
    var toolbarSpacing: CGFloat = 10
    /// Shown as the expand button when set.
    var onExpand: (() -> Void)?
    var onFocusChange: (Bool) -> Void = { _ in }

    @State private var controller = NoteEditorController()
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let note = store.currentNote {
                if store.unreadableIDs.contains(note.id) {
                    Text("This note could not be read. Its file was left untouched.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    NoteTextEditor(
                        store: store,
                        noteID: note.id,
                        revision: store.revision(of: note.id),
                        codeMode: settings.codeMode,
                        showsScrollIndicator: settings.showsScrollIndicator,
                        controller: controller,
                        inset: textInset,
                        onFocusChange: onFocusChange
                    )
                }
            } else {
                Spacer(minLength: 0)
            }

            status

            NoteToolbar(
                store: store,
                settings: settings,
                controller: controller,
                spacing: toolbarSpacing,
                onExpand: onExpand,
                onExport: export
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var status: some View {
        if let deleted = store.recentlyDeleted {
            HStack(spacing: 6) {
                Text("Deleted “\(deleted.summary.displayTitle)”")
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 4)
                Button("Undo") { store.undoDelete() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.yellow)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 11))
        } else if let error = exportError ?? store.lastError {
            Text(error)
                .font(.system(size: 9))
                .foregroundStyle(.red)
                .lineLimit(1)
                .help(error)
        }
    }

    private func export(_ format: NoteExporter.Format) {
        guard let note = store.currentNote, let content = store.content(of: note.id) else { return }
        do {
            _ = try NoteExporter.export(note, content: content, as: format, codeMode: settings.codeMode)
            exportError = nil
        } catch {
            exportError = "The note could not be exported: \(error.localizedDescription)"
        }
    }
}

private struct NoteToolbar: View {
    let store: NoteStore
    let settings: NotesSettings
    let controller: NoteEditorController
    let spacing: CGFloat
    let onExpand: (() -> Void)?
    let onExport: (NoteExporter.Format) -> Void

    var body: some View {
        let isEditable = store.currentNote.map { !store.unreadableIDs.contains($0.id) } ?? false

        HStack(spacing: spacing) {
            if settings.codeMode {
                Label(controller.language?.displayName ?? "Plain text", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            } else {
                formatting
                    .disabled(!isEditable)
            }

            Spacer(minLength: 0)

            notesMenu

            if let onExpand {
                ToolbarIcon(systemImage: "arrow.up.left.and.arrow.down.right", action: onExpand)
                    .help("Open in a window")
            }
        }
        .frame(height: 18)
    }

    @ViewBuilder
    private var formatting: some View {
        let format = controller.format

        Menu {
            Picker("Color", selection: Binding(
                get: { NoteStyle.paletteColor(matching: format.color)?.id },
                set: { name in
                    guard let color = NoteStyle.palette.first(where: { $0.id == name }) else { return }
                    controller.setColor(color.color)
                }
            )) {
                ForEach(NoteStyle.palette) { color in
                    Label { Text(color.name) } icon: { Image(nsImage: color.swatch) }
                        .tag(Optional(color.id))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Circle()
                .fill(Color(nsColor: format.color))
                .frame(width: 11, height: 11)
                .overlay { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1) }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Text color")

        Menu {
            Picker("Size", selection: Binding(get: { format.fontSize }, set: { controller.setFontSize($0) })) {
                ForEach(NoteStyle.sizes, id: \.self) { size in
                    Text("\(Int(size)) pt").tag(size)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Text size")

        FormatToggle(label: Text("B").bold(), isOn: format.isBold, help: "Bold (⌘B)", action: controller.toggleBold)
        FormatToggle(label: Text("I").italic(), isOn: format.isItalic, help: "Italic (⌘I)", action: controller.toggleItalic)
        FormatToggle(label: Text("U").underline(), isOn: format.isUnderlined, help: "Underline (⌘U)", action: controller.toggleUnderline)
    }

    private var notesMenu: some View {
        Menu {
            Section("Notes") {
                ForEach(store.notes) { note in
                    Button {
                        store.select(note.id)
                    } label: {
                        if note.id == store.currentID {
                            Label(note.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(note.displayTitle)
                        }
                    }
                }
            }
            Divider()
            Button("New Note", systemImage: "square.and.pencil") { store.create() }
            Menu("Export") {
                ForEach(NoteExporter.Format.allCases) { format in
                    Button(format.menuTitle) { onExport(format) }
                }
            }
            .disabled(store.currentNote.map { store.unreadableIDs.contains($0.id) } ?? true)
            Divider()
            Button("Delete Note", systemImage: "trash", role: .destructive) {
                if let id = store.currentID { store.delete(id) }
            }
            .disabled(store.currentID == nil)
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Notes")
    }
}

private struct FormatToggle: View {
    let label: Text
    let isOn: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(isOn ? .black : .white.opacity(0.75))
                .frame(width: 18, height: 18)
                .background(isOn ? AnyShapeStyle(.yellow) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 4))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ToolbarIcon: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 18, height: 18)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
