import AppKit
import UniformTypeIdentifiers

/// Saves a note to a file the user picks.
@MainActor
enum NoteExporter {
    enum Format: CaseIterable, Identifiable {
        case markdown
        case plainText
        case rtf

        var id: Self { self }

        var menuTitle: String {
            switch self {
            case .markdown: "Markdown…"
            case .plainText: "Plain Text…"
            case .rtf: "Rich Text (RTF)…"
            }
        }

        var fileExtension: String {
            switch self {
            case .markdown: "md"
            case .plainText: "txt"
            case .rtf: "rtf"
            }
        }

        var contentType: UTType {
            switch self {
            // Markdown has no system-declared type; one derived from the extension still filters the panel.
            case .markdown: UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
            case .plainText: .plainText
            case .rtf: .rtf
            }
        }
    }

    /// Asks where to save and writes the note; `false` when the user cancels.
    static func export(_ note: NoteSummary, content: NSAttributedString, as format: Format, codeMode: Bool) throws -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Note"
        panel.nameFieldStringValue = "\(fileName(for: note)).\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        // An agent app is not active while the notch is used; without activating, the panel opens behind other apps.
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try data(for: content, as: format, codeMode: codeMode).write(to: url, options: .atomic)
        return true
    }

    private static func data(for content: NSAttributedString, as format: Format, codeMode: Bool) throws -> Data {
        switch format {
        case .markdown:
            return Data(markdown(from: content, codeMode: codeMode).utf8)
        case .plainText:
            return Data(content.string.utf8)
        case .rtf:
            let document = codeMode
                ? NSAttributedString(string: content.string, attributes: [.font: NoteStyle.codeFont])
                : NoteStyle.preparedForExport(content)
            return try document.data(
                from: NSRange(location: 0, length: document.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }
    }

    /// Code becomes one fenced block; rich text keeps bold and italic. Markdown has no underline, sizes or colors.
    private static func markdown(from content: NSAttributedString, codeMode: Bool) -> String {
        if codeMode {
            let tag = SyntaxHighlighter.detectLanguage(in: content.string)?.markdownTag ?? ""
            return "```\(tag)\n\(content.string)\n```\n"
        }

        var output = ""
        let text = content.string as NSString
        content.enumerateAttribute(.font, in: NSRange(location: 0, length: content.length)) { value, range, _ in
            let traits = (value as? NSFont)?.fontDescriptor.symbolicTraits ?? []
            let marker = switch (traits.contains(.bold), traits.contains(.italic)) {
            case (true, true): "***"
            case (true, false): "**"
            case (false, true): "*"
            case (false, false): ""
            }
            output += emphasize(escape(text.substring(with: range)), with: marker)
        }
        return output
    }

    /// Emphasis cannot span lines or start or end with a space, so each line's trimmed text is wrapped on its own.
    private static func emphasize(_ text: String, with marker: String) -> String {
        guard !marker.isEmpty else { return text }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let core = line.trimmingCharacters(in: .whitespaces)
                guard !core.isEmpty, let start = line.range(of: core) else { return String(line) }
                return line[..<start.lowerBound] + marker + core + marker + line[start.upperBound...]
            }
            .joined(separator: "\n")
    }

    private static func escape(_ text: String) -> String {
        var escaped = ""
        for character in text {
            if "\\*_`".contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        return escaped
    }

    private static func fileName(for note: NoteSummary) -> String {
        let name = note.displayTitle.map { "/:".contains($0) ? "-" : $0 }
        return String(name)
    }
}
