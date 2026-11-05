import AppKit
import Observation
import SwiftUI

/// Formatting of the selection, as the toolbar shows it.
struct NoteSelectionFormat: Equatable {
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var fontSize: CGFloat
    var color: NSColor
}

/// Connects one editor's text view to its toolbar: the toolbar reads the selection's format and calls the actions.
@MainActor
@Observable
final class NoteEditorController {
    private(set) var format = NoteSelectionFormat(
        isBold: false,
        isItalic: false,
        isUnderlined: false,
        fontSize: NoteStyle.defaultSize,
        color: NoteStyle.textColor
    )
    /// Language detected in code mode; `nil` shows plain monospaced text.
    private(set) var language: CodeLanguage?

    @ObservationIgnored fileprivate weak var textView: NoteTextView?

    func toggleBold() {
        toggleTrait(.bold)
    }

    func toggleItalic() {
        toggleTrait(.italic)
    }

    func toggleUnderline() {
        let adding = !format.isUnderlined
        let style = NSUnderlineStyle.single.rawValue
        changeSelection { storage, range in
            if adding {
                storage.addAttribute(.underlineStyle, value: style, range: range)
            } else {
                storage.removeAttribute(.underlineStyle, range: range)
            }
        } typing: { attributes in
            attributes[.underlineStyle] = adding ? style : nil
        }
    }

    func setFontSize(_ size: CGFloat) {
        changeFonts { font in
            let traits = font.fontDescriptor.symbolicTraits
            return NoteStyle.font(size: size, bold: traits.contains(.bold), italic: traits.contains(.italic))
        }
    }

    func setColor(_ color: NSColor) {
        changeSelection { storage, range in
            storage.addAttribute(.foregroundColor, value: color, range: range)
        } typing: { attributes in
            attributes[.foregroundColor] = color
        }
    }

    fileprivate func refreshFormat() {
        guard let textView else { return }
        // NSTextView keeps the typing attributes in step with the selection: the first selected character, or the
        // one before the insertion point.
        let attributes = textView.typingAttributes
        let font = attributes[.font] as? NSFont ?? NoteStyle.bodyFont
        let traits = font.fontDescriptor.symbolicTraits
        let current = NoteSelectionFormat(
            isBold: traits.contains(.bold),
            isItalic: traits.contains(.italic),
            isUnderlined: (attributes[.underlineStyle] as? Int ?? 0) != 0,
            fontSize: font.pointSize,
            color: attributes[.foregroundColor] as? NSColor ?? NoteStyle.textColor
        )
        if current != format { format = current }
    }

    fileprivate func setLanguage(_ language: CodeLanguage?) {
        if language != self.language { self.language = language }
    }

    private func toggleTrait(_ trait: NSFontDescriptor.SymbolicTraits) {
        let adding = trait == .bold ? !format.isBold : !format.isItalic
        changeFonts { font in
            var traits = font.fontDescriptor.symbolicTraits
            if adding { traits.insert(trait) } else { traits.remove(trait) }
            return NoteStyle.font(size: font.pointSize, bold: traits.contains(.bold), italic: traits.contains(.italic))
        }
    }

    private func changeFonts(_ transform: @escaping (NSFont) -> NSFont) {
        changeSelection { storage, range in
            storage.enumerateAttribute(.font, in: range) { value, run, _ in
                storage.addAttribute(.font, value: transform(value as? NSFont ?? NoteStyle.bodyFont), range: run)
            }
        } typing: { attributes in
            attributes[.font] = transform(attributes[.font] as? NSFont ?? NoteStyle.bodyFont)
        }
    }

    /// Restyles the selected text as one undoable edit, or what is typed next when nothing is selected.
    private func changeSelection(
        _ change: (NSTextStorage, NSRange) -> Void,
        typing: (inout [NSAttributedString.Key: Any]) -> Void
    ) {
        guard let textView, let storage = textView.textStorage, textView.isEditable, !textView.isCodeMode else { return }
        let ranges = textView.selectedRanges.map(\.rangeValue).filter { $0.length > 0 }

        if ranges.isEmpty {
            var attributes = textView.typingAttributes
            typing(&attributes)
            textView.typingAttributes = attributes
        } else {
            guard textView.shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: nil) else { return }
            storage.beginEditing()
            for range in ranges {
                change(storage, range)
            }
            storage.endEditing()
            // Reports the edit to the delegate, which saves it.
            textView.didChangeText()
        }
        refreshFormat()
    }
}

/// Text view of a note. The app has no main menu, so the editing shortcuts a menu would provide are handled here.
final class NoteTextView: NSTextView {
    var isCodeMode = false
    weak var controller: NoteEditorController?
    var onFocusChange: ((Bool) -> Void)?
    private(set) var isFocused = false

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { setFocused(true) }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { setFocused(false) }
        return resigned
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, window?.firstResponder === self,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

        switch (modifiers, key) {
        case ([.command], "x"): cut(nil)
        case ([.command], "c"): copy(nil)
        case ([.command], "v"): paste(nil)
        case ([.command, .option, .shift], "v"): pasteAsPlainText(nil)
        case ([.command], "a"): selectAll(nil)
        case ([.command], "z"):
            guard let undoManager, undoManager.canUndo else { return true }
            undoManager.undo()
        case ([.command, .shift], "z"):
            guard let undoManager, undoManager.canRedo else { return true }
            undoManager.redo()
        case ([.command], "b") where !isCodeMode: controller?.toggleBold()
        case ([.command], "i") where !isCodeMode: controller?.toggleItalic()
        case ([.command], "u") where !isCodeMode: controller?.toggleUnderline()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    fileprivate func setFocused(_ focused: Bool) {
        guard isFocused != focused else { return }
        isFocused = focused
        onFocusChange?(focused)
    }
}

/// TextKit 2 editor for one note, kept in sync with the store both ways: typing saves into the store, and changes
/// made by another editor of the same note (the expanded window, another screen's notch) reload here.
struct NoteTextEditor: NSViewRepresentable {
    let store: NoteStore
    let noteID: UUID
    /// Read by the parent view so SwiftUI updates this editor when the note changes.
    let revision: NoteRevision
    let codeMode: Bool
    let showsScrollIndicator: Bool
    let controller: NoteEditorController
    var inset = CGSize(width: 0, height: 2)
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NoteTextView(usingTextLayoutManager: true)
        textView.drawsBackground = false
        textView.insertionPointColor = .white
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.importsGraphics = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = inset
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        context.coordinator.textView = textView
        update(scrollView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        update(scrollView, coordinator: context.coordinator)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        // A view removed while focused never resigns first responder, which would leave the notch pinned open.
        coordinator.textView?.setFocused(false)
    }

    private func update(_ scrollView: NSScrollView, coordinator: Coordinator) {
        scrollView.hasVerticalScroller = showsScrollIndicator
        guard let textView = coordinator.textView else { return }
        textView.controller = controller
        textView.onFocusChange = onFocusChange
        controller.textView = textView

        let previous = coordinator.target
        coordinator.store = store
        coordinator.target = Coordinator.Target(noteID: noteID, codeMode: codeMode)
        coordinator.controller = controller

        if previous != coordinator.target {
            coordinator.reload(keepingSelection: false)
        } else if revision != coordinator.appliedRevision {
            // The editor that typed the change already shows it; reloading would reset its selection and undo.
            if revision.origin == coordinator.editorID {
                coordinator.appliedRevision = revision
            } else {
                coordinator.reload(keepingSelection: true)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        struct Target: Equatable {
            let noteID: UUID
            let codeMode: Bool
        }

        /// Tags this editor's changes in the store.
        let editorID = UUID()
        weak var textView: NoteTextView?
        weak var store: NoteStore?
        weak var controller: NoteEditorController?
        var target: Target?
        var appliedRevision: NoteRevision?

        func reload(keepingSelection: Bool) {
            guard let textView, let storage = textView.textStorage, let store, let target else { return }
            let selection = textView.selectedRange()
            let content = store.content(of: target.noteID)

            textView.isCodeMode = target.codeMode
            // Set before the text: turning rich text off makes the existing text's attributes uniform.
            textView.isRichText = !target.codeMode
            textView.isEditable = content != nil
            textView.isContinuousSpellCheckingEnabled = !target.codeMode
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = !target.codeMode

            if target.codeMode {
                storage.setAttributedString(NSAttributedString(string: content?.string ?? ""))
                highlight()
            } else {
                storage.setAttributedString(content.map(NoteStyle.normalizedForEditing) ?? NSAttributedString())
            }
            textView.typingAttributes = target.codeMode ? NoteStyle.codeTypingAttributes : NoteStyle.richTypingAttributes
            // Undo steps recorded against the previous text would corrupt the new one.
            textView.undoManager?.removeAllActions()

            let length = storage.length
            if keepingSelection {
                let location = min(selection.location, length)
                textView.setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
            } else {
                textView.setSelectedRange(NSRange(location: length, length: 0))
            }
            appliedRevision = store.revision(of: target.noteID)
            controller?.refreshFormat()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, let store, let target else { return }
            // Recoloring while an input method composes text would break the composition.
            if target.codeMode && !textView.hasMarkedText() {
                highlight()
            }
            let content = target.codeMode
                ? NSAttributedString(string: textView.string)
                : NSAttributedString(attributedString: textView.attributedString())
            store.setContent(content, of: target.noteID, origin: editorID)
            appliedRevision = store.revision(of: target.noteID)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller?.refreshFormat()
        }

        private func highlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let language = SyntaxHighlighter.detectLanguage(in: storage.string)
            SyntaxHighlighter.highlight(storage, language: language)
            textView.typingAttributes = NoteStyle.codeTypingAttributes
            controller?.setLanguage(language)
        }
    }
}
