import AppKit

/// Languages the code mode recognizes and highlights.
enum CodeLanguage: CaseIterable {
    case swift
    case javascript
    case python
    case json
    case shell

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .javascript: "JavaScript"
        case .python: "Python"
        case .json: "JSON"
        case .shell: "Shell"
        }
    }

    /// Info string of a Markdown fenced code block.
    var markdownTag: String {
        switch self {
        case .swift: "swift"
        case .javascript: "javascript"
        case .python: "python"
        case .json: "json"
        case .shell: "sh"
        }
    }
}

/// Small regular-expression highlighter for the code mode. It colors keywords, types, numbers, strings and comments;
/// it does not parse, so unusual constructs may be colored imperfectly. Colors are applied to the text storage only
/// while editing: code-mode notes are saved as plain text, so the highlighting never reaches the file.
@MainActor
enum SyntaxHighlighter {
    /// Detection only looks at the start of the note; enough to tell the languages apart and cheap on every keystroke.
    private static let detectionLimit = 4000
    /// Below this score the text reads as prose and stays uncolored.
    private static let minimumScore = 3
    /// One clue repeated many times should not outweigh several different clues.
    private static let maximumHitsPerSignal = 3

    /// Best guess for `text`, or `nil` when no language stands out.
    static func detectLanguage(in text: String) -> CodeLanguage? {
        let sample = String(text.prefix(detectionLimit))
        let range = NSRange(sample.startIndex..., in: sample)
        let scored = CodeLanguage.allCases.map { language in
            let score = signals(for: language).reduce(0) { total, signal in
                let hits = min(signal.regex.numberOfMatches(in: sample, range: range), maximumHitsPerSignal)
                return total + hits * signal.weight
            }
            return (language, score)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= minimumScore else { return nil }
        return best.0
    }

    /// Resets `storage` to the code font and colors it for `language`; plain monospaced text when `nil`.
    static func highlight(_ storage: NSTextStorage, language: CodeLanguage?) {
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(NoteStyle.codeTypingAttributes, range: whole)
        if let language {
            grammar(for: language).apply(to: storage, range: whole)
        }
        storage.endEditing()
    }

    // MARK: - Detection

    private struct Signal {
        let regex: NSRegularExpression
        let weight: Int

        init(_ pattern: String, _ weight: Int) {
            regex = SyntaxHighlighter.regex(pattern, .anchorsMatchLines)
            self.weight = weight
        }
    }

    private static func signals(for language: CodeLanguage) -> [Signal] {
        switch language {
        case .swift: swiftSignals
        case .javascript: javascriptSignals
        case .python: pythonSignals
        case .json: jsonSignals
        case .shell: shellSignals
        }
    }

    private static let swiftSignals = [
        Signal(#"^\s*import\s+(SwiftUI|Foundation|AppKit|UIKit|Combine|Observation)\b"#, 4),
        Signal(#"\bfunc\s+\w+\s*[<(]"#, 3),
        Signal(#"@(MainActor|State|Observable|Published|objc|escaping|ViewBuilder|Binding|Environment)\b"#, 3),
        Signal(#"\bguard\b.*\belse\b"#, 3),
        Signal(#"\bif\s+let\b"#, 3),
        Signal(#"\b(struct|extension|protocol)\s+[A-Z]\w*"#, 2),
        Signal(#"->\s*[A-Z]\w*"#, 2),
        Signal(#"\b(let|var)\s+\w+\s*:\s*[A-Z]\w*"#, 2),
    ]

    private static let javascriptSignals = [
        Signal(#"^\s*import\s+.*\s+from\s+['"]"#, 4),
        Signal(#"\bconsole\.\w+\("#, 4),
        Signal(#"\bfunction\b"#, 3),
        Signal(#"\bexport\s+(default|const|function|class|interface|type)\b"#, 3),
        Signal(#"===|!=="#, 3),
        Signal(#"\brequire\(\s*['"]"#, 3),
        Signal(#"\bconst\s+\w+\s*="#, 2),
        Signal(#"=>"#, 2),
        Signal(#":\s*(string|number|boolean|any|void)\b"#, 2),
        Signal(#";\s*$"#, 1),
    ]

    private static let pythonSignals = [
        Signal(#"^\s*def\s+\w+\s*\(.*\)\s*(->\s*[^:]+)?:\s*$"#, 4),
        Signal(#"^\s*(class\s+\w+(\(.*\))?|if\s.+|elif\s.+|else|for\s.+\sin\s.+|while\s.+|try|except.*|with\s.+):\s*$"#, 3),
        Signal(#"\b(elif|None|True|False|lambda|pass|nonlocal)\b"#, 2),
        Signal(#"^\s*from\s+[\w.]+\s+import\s+"#, 3),
        Signal(#"\bself\.\w+"#, 1),
        Signal(#"\bprint\("#, 1),
    ]

    private static let jsonSignals = [
        Signal(#"\A\s*[\{\[]"#, 2),
        Signal(#"\A\s*[\{\[][\s\S]*[\}\]]\s*\z"#, 2),
        Signal(#"^\s*"[^"\n]*"\s*:"#, 2),
    ]

    private static let shellSignals = [
        Signal(#"\A#!.*\b(ba|z|k|fi)?sh\b"#, 6),
        Signal(#"^\s*\$\s+\w"#, 3),
        Signal(#"\b(fi|esac|done|then)\b"#, 3),
        Signal(#"^\s*(echo|sudo|brew|grep|chmod|mkdir|curl|export|cd|ls|rm|cp|mv)\s"#, 2),
        Signal(#"\$\{\w+\}"#, 2),
        Signal(#"\s(&&|\|\|)\s|\|\s*(grep|sort|head|tail|xargs|awk|sed)\b"#, 1),
    ]

    // MARK: - Highlighting

    private enum Palette {
        static let keyword = NSColor(srgbRed: 1.0, green: 0.48, blue: 0.70, alpha: 1)
        static let type = NSColor(srgbRed: 0.36, green: 0.85, blue: 1.0, alpha: 1)
        static let string = NSColor(srgbRed: 0.99, green: 0.42, blue: 0.36, alpha: 1)
        static let number = NSColor(srgbRed: 0.82, green: 0.75, blue: 0.41, alpha: 1)
        static let comment = NSColor(srgbRed: 0.50, green: 0.55, blue: 0.60, alpha: 1)
        static let attribute = NSColor(srgbRed: 0.99, green: 0.56, blue: 0.25, alpha: 1)
        static let variable = NSColor(srgbRed: 0.63, green: 0.40, blue: 0.90, alpha: 1)
    }

    private struct Rule {
        let regex: NSRegularExpression
        let color: NSColor

        init(_ pattern: String, _ color: NSColor) {
            regex = SyntaxHighlighter.regex(pattern, .anchorsMatchLines)
            self.color = color
        }
    }

    private struct Grammar {
        /// Keywords, types and numbers, applied first.
        let rules: [Rule]
        /// Comments (group 1) and strings (group 2) in one alternation, so whichever starts first wins: a `//` inside
        /// a string stays a string and a quote inside a comment stays a comment.
        let literals: NSRegularExpression
        /// Applied over the literals, for tokens that are strings with another role, like JSON keys.
        var overrides: [Rule] = []

        func apply(to storage: NSTextStorage, range: NSRange) {
            let string = storage.string
            for rule in rules {
                color(rule, in: storage, string: string, range: range)
            }
            for match in literals.matches(in: string, range: range) {
                if match.range(at: 1).location != NSNotFound {
                    storage.addAttribute(.foregroundColor, value: Palette.comment, range: match.range(at: 1))
                } else if match.range(at: 2).location != NSNotFound {
                    storage.addAttribute(.foregroundColor, value: Palette.string, range: match.range(at: 2))
                }
            }
            for rule in overrides {
                color(rule, in: storage, string: string, range: range)
            }
        }

        private func color(_ rule: Rule, in storage: NSTextStorage, string: String, range: NSRange) {
            for match in rule.regex.matches(in: string, range: range) {
                storage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
            }
        }
    }

    private static func grammar(for language: CodeLanguage) -> Grammar {
        switch language {
        case .swift: swiftGrammar
        case .javascript: javascriptGrammar
        case .python: pythonGrammar
        case .json: jsonGrammar
        case .shell: shellGrammar
        }
    }

    private static let number = #"\b(0x[0-9A-Fa-f_]+|\d[\d_]*(\.\d+)?([eE][+-]?\d+)?)\b"#

    private static func keywords(_ words: [String]) -> String {
        #"\b("# + words.joined(separator: "|") + #")\b"#
    }

    private static let swiftGrammar = Grammar(
        rules: [
            Rule(number, Palette.number),
            Rule(#"\b[A-Z][A-Za-z0-9_]*\b"#, Palette.type),
            Rule(keywords([
                "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
                "default", "defer", "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate", "final",
                "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "is", "lazy", "let",
                "mutating", "nil", "nonisolated", "open", "operator", "override", "private", "protocol", "public",
                "repeat", "rethrows", "return", "self", "Self", "some", "static", "struct", "subscript", "super",
                "switch", "throw", "throws", "true", "try", "typealias", "var", "weak", "where", "while",
            ]), Palette.keyword),
            Rule(#"@\w+"#, Palette.attribute),
        ],
        literals: regex(#"(//.*|/\*[\s\S]*?\*/)|("""[\s\S]*?"""|"(?:[^"\\\n]|\\.)*")"#, .anchorsMatchLines)
    )

    private static let javascriptGrammar = Grammar(
        rules: [
            Rule(number, Palette.number),
            Rule(#"\b[A-Z][A-Za-z0-9_]*\b"#, Palette.type),
            Rule(keywords([
                "abstract", "as", "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger",
                "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally", "for", "from",
                "function", "if", "implements", "import", "in", "instanceof", "interface", "let", "new", "null", "of",
                "private", "protected", "public", "readonly", "return", "static", "super", "switch", "this", "throw",
                "true", "try", "type", "typeof", "undefined", "var", "void", "while", "yield",
            ]), Palette.keyword),
        ],
        literals: regex(#"(//.*|/\*[\s\S]*?\*/)|("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`)"#, .anchorsMatchLines)
    )

    private static let pythonGrammar = Grammar(
        rules: [
            Rule(number, Palette.number),
            Rule(keywords([
                "and", "as", "assert", "async", "await", "break", "case", "class", "continue", "def", "del", "elif",
                "else", "except", "False", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda",
                "match", "None", "nonlocal", "not", "or", "pass", "raise", "return", "self", "True", "try", "while",
                "with", "yield",
            ]), Palette.keyword),
            Rule(#"^\s*@[\w.]+"#, Palette.attribute),
        ],
        literals: regex(
            #"(#.*)|("""[\s\S]*?"""|'''[\s\S]*?'''|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')"#,
            .anchorsMatchLines
        )
    )

    private static let jsonGrammar = Grammar(
        rules: [
            Rule(number, Palette.number),
            Rule(keywords(["true", "false", "null"]), Palette.keyword),
        ],
        // JSON has no comments; group 1 never matches.
        literals: regex(#"(?!)()|("(?:[^"\\\n]|\\.)*")"#),
        overrides: [Rule(#""(?:[^"\\\n]|\\.)*"(?=\s*:)"#, Palette.type)]
    )

    private static let shellGrammar = Grammar(
        rules: [
            Rule(keywords([
                "case", "do", "done", "echo", "elif", "else", "esac", "exit", "export", "fi", "for", "function", "if",
                "in", "local", "return", "sudo", "then", "until", "while",
            ]), Palette.keyword),
            Rule(#"(?<=\s)--?[A-Za-z][\w-]*"#, Palette.type),
            Rule(#"\$\{[^}\n]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@#?$!*-]"#, Palette.variable),
        ],
        literals: regex(#"((?:^|(?<=\s))#.*)|("(?:[^"\\]|\\.)*"|'[^']*')"#, .anchorsMatchLines)
    )

    /// Patterns are fixed in the source, so an invalid one is a programming error caught on first use.
    nonisolated fileprivate static func regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            preconditionFailure("Invalid built-in pattern \(pattern): \(error)")
        }
    }
}
