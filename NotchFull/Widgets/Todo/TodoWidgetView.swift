import SwiftUI

struct TodoWidgetView: View {
    let store: TodoStore
    let interaction: NotchInteraction

    @State private var draft = ""
    @State private var isAdding = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To-dos")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.sortedItems) { item in
                        TodoRow(item: item) { store.toggle(item.id) }
                            .contextMenu {
                                Button("Delete", role: .destructive) { store.delete(item.id) }
                                Button("Clear completed") { store.clearCompleted() }
                            }
                    }
                    if store.items.isEmpty && !isAdding {
                        Text("Nothing to do.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            if let error = store.lastError {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .help(error)
            }

            if isAdding {
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
        .onChange(of: isFieldFocused) { _, focused in
            interaction.isEditingText = focused
            if !focused && draft.isEmpty { isAdding = false }
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
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isDone ? AnyShapeStyle(.orange) : AnyShapeStyle(.orange.opacity(0.9)))
                    .contentTransition(.symbolEffect(.replace))
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .strikethrough(item.isDone)
                    .foregroundStyle(.white.opacity(item.isDone ? 0.4 : 0.95))
                    .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
