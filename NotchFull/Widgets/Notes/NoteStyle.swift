import AppKit

/// A text color offered by the formatting toolbar.
struct NoteColor: Identifiable {
    let name: String
    let color: NSColor
    /// Menus draw SF Symbols as monochrome templates, so the swatch is a colored image of its own.
    let swatch: NSImage

    init(name: String, color: NSColor) {
        self.name = name
        self.color = color
        swatch = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
    }

    var id: String { name }
}

/// Text styling shared by the notch widget and the note window. Notes are always shown on a dark surface.
@MainActor
enum NoteStyle {
    static let defaultSize: CGFloat = 13
    static let sizes: [CGFloat] = [11, 13, 15, 18, 24, 32]
    static let codeSize: CGFloat = 12
    static let textColor = NSColor.white

    static let palette: [NoteColor] = [
        NoteColor(name: "White", color: textColor),
        NoteColor(name: "Gray", color: .systemGray),
        NoteColor(name: "Yellow", color: .systemYellow),
        NoteColor(name: "Orange", color: .systemOrange),
        NoteColor(name: "Red", color: .systemRed),
        NoteColor(name: "Pink", color: .systemPink),
        NoteColor(name: "Purple", color: .systemPurple),
        NoteColor(name: "Blue", color: .systemBlue),
        NoteColor(name: "Green", color: .systemGreen),
    ]

    static var bodyFont: NSFont { font(size: defaultSize, bold: false, italic: false) }
    static var codeFont: NSFont { .monospacedSystemFont(ofSize: codeSize, weight: .regular) }

    static var richTypingAttributes: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: textColor]
    }

    static var codeTypingAttributes: [NSAttributedString.Key: Any] {
        [.font: codeFont, .foregroundColor: textColor]
    }

    /// The system font in `size` with the requested traits; the toolbar only offers the system font.
    static func font(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        let base = NSFont.systemFont(ofSize: size)
        guard !traits.isEmpty else { return base }
        // A face the system font lacks yields nil; the plain face keeps the text readable.
        return NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits), size: size) ?? base
    }

    /// Rich content ready for the editor. RTF writes the system font as Helvetica Neue, so every font is mapped back
    /// to the system font with its size and traits; text without a color gets the default one, readable on dark.
    static func normalizedForEditing(_ content: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: content)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: whole) { value, range, _ in
            let font = value as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let mapped = Self.font(size: font?.pointSize ?? defaultSize, bold: traits.contains(.bold), italic: traits.contains(.italic))
            result.addAttribute(.font, value: mapped, range: range)
        }
        result.enumerateAttribute(.foregroundColor, in: whole) { value, range, _ in
            if value == nil { result.addAttribute(.foregroundColor, value: textColor, range: range) }
        }
        return result
    }

    /// Exported RTF opens in light document editors, where the default white text would be invisible; dropping it
    /// lets those apps use their own default color.
    static func preparedForExport(_ content: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: content)
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if let color = value as? NSColor, isSame(color, textColor) {
                result.removeAttribute(.foregroundColor, range: range)
            }
        }
        return result
    }

    static func paletteColor(matching color: NSColor) -> NoteColor? {
        palette.first { isSame($0.color, color) }
    }

    /// Colors read back from RTF come in other color spaces, so they are compared by their sRGB components.
    private static func isSame(_ lhs: NSColor, _ rhs: NSColor) -> Bool {
        guard let lhs = lhs.usingColorSpace(.sRGB), let rhs = rhs.usingColorSpace(.sRGB) else { return false }
        let tolerance: CGFloat = 0.01
        return abs(lhs.redComponent - rhs.redComponent) < tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) < tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) < tolerance
    }
}
