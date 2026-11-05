import SwiftUI

struct TodoWidgetView: View {
    let store: TodoStore
    let interaction: NotchInteraction
    let pomodoro: PomodoroTimer

    @State private var draft = ""
    @State private var isAdding = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To-dos")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.visibleItems) { item in
                        TodoRow(item: item, store: store, pomodoro: pomodoro)
                    }
                    if store.visibleItems.isEmpty && !isAdding {
                        Text("Nothing to do.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: isFieldFocused) { _, focused in
            interaction.isEditingText = focused
            if !focused && draft.isEmpty { isAdding = false }
        }
        .animation(.smooth(duration: 0.2), value: store.visibleItems)
    }

    @ViewBuilder
    private var footer: some View {
        if let deleted = store.recentlyDeleted {
            HStack(spacing: 6) {
                Text("Deleted “\(deleted.title)”")
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 4)
                Button("Undo") { store.undoDelete() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 11))
            .transition(.opacity)
        } else if let error = store.lastError {
            Text(error)
                .font(.system(size: 9))
                .foregroundStyle(.red)
                .lineLimit(1)
                .help(error)
        } else if isAdding {
            TextField("New task", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFieldFocused)
                .onSubmit(commit)
                .onExitCommand(perform: cancel)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1), in: .capsule)
        } else {
            Button {
                isAdding = true
                isFieldFocused = true
            } label: {
                Label("Add a task", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.18), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private func commit() {
        store.add(draft)
        draft = ""
        isFieldFocused = true
    }

    private func cancel() {
        draft = ""
        isAdding = false
        isFieldFocused = false
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let store: TodoStore
    let pomodoro: PomodoroTimer

    @State private var isHovered = false
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(item.id)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.orange)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            if item.isPriority && !item.isDone {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.orange)
            }

            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .strikethrough(item.isDone)
                .foregroundStyle(.white.opacity(item.isDone ? 0.4 : 0.95))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(.white.opacity(isDropTarget ? 0.12 : 0), in: .rect(cornerRadius: 6))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .draggable(item.id.uuidString)
        .dropDestination(for: String.self) { ids, _ in
            guard let raw = ids.first, let dragged = UUID(uuidString: raw) else { return false }
            store.move(dragged, onto: item.id)
            return true
        } isTargeted: { isDropTarget = $0 }
        .contextMenu {
            focusMenu
            Button(item.isPriority ? "Remove priority" : "Mark as priority") { store.togglePriority(item.id) }
            Divider()
            Button("Delete", role: .destructive) { store.delete(item.id) }
        }
    }

    // Hover swaps the duration chip for the actions, so deleting never needs the context menu.
    @ViewBuilder
    private var trailing: some View {
        if isHovered {
            HStack(spacing: 6) {
                Menu {
                    focusMenu
                } label: {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Focus time")

                Button {
                    store.delete(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 16, height: 16)
                        .background(.white.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        } else if let minutes = item.focusMinutes {
            let isFocusing = pomodoro.taskID == item.id
            // The chip starts a focus session of that length for this task.
            Button {
                pomodoro.startFocus(minutes: minutes, taskID: item.id, title: item.title)
            } label: {
                Text("\(minutes)m")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isFocusing ? .orange : .white.opacity(item.isDone ? 0.3 : 0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isFocusing ? Color.orange.opacity(0.2) : .white.opacity(0.1), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(item.isDone)
            .help("Start a \(minutes)-minute focus session")
        }
    }

    @ViewBuilder
    private var focusMenu: some View {
        Section("Focus time") {
            ForEach(TodoSettings.focusMinuteOptions, id: \.self) { minutes in
                Button("\(minutes) min") { store.setFocusMinutes(minutes, for: item.id) }
            }
            if item.focusMinutes != nil {
                Button("None") { store.setFocusMinutes(nil, for: item.id) }
            }
        }
    }
}
