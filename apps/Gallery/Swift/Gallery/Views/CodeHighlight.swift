// Colouring Swift source, on this side of the boundary.
//
// A MAUI Label has ONE TextColor, so text in six colours is six Spans - which is
// what `Label.formattedText` is for. This file turns a snippet into those runs.
//
// ASCII only, on purpose. Deciding what is a letter with `Character.isLetter`
// would work, but the whole question of which Unicode tables that reaches is one
// this repository would rather not open - the README's rule against ICU-backed
// APIs, and the per-platform measurements behind it, say why. Every
// keyword and every type name in a Swift snippet is ASCII, and anything else
// falls through as plain text, which is the right answer for it anyway.

import StateUI

/// Which language's words are drawn as keywords. The scanner is shared -
/// comments, strings, attributes, capitalised names and numbers read the
/// same in both - only the vocabulary differs.
enum CodeLanguage {
    /// The default: every sample's own code.
    case swift

    /// On request: the C# half an interop sample shows under IN C#.
    case csharp
}

/// One run of source that is all the same colour.
struct CodeRun {
    /// The characters, exactly as they were written - whitespace included, so
    /// joining every run back up gives the snippet.
    let text: String

    /// What to draw it in.
    let colour: Color
}

/// Splits a Swift snippet into coloured runs.
///
/// Deliberately shallow: one pass, no parsing, no notion of scope. It reads
/// comments, string literals, attributes, keywords, capitalised names and
/// numbers, and calls everything else plain. That is enough to make a snippet
/// scannable and cannot be wrong about code it does not understand - the worst
/// it does is leave something uncoloured.
enum CodeHighlight {
    /// The colours, each right on both themes. `Color(light:dark:)` is bound
    /// rather than resolved, so nothing here has to know which theme is on.
    private enum Ink {
        /// `let`, `func`, `if` - the words the language owns.
        static let keyword = Color(light: Color("#AF00DB"), dark: Color("#C586C0"))

        /// `Label`, `Basket` - anything starting with a capital.
        static let type = Color(light: Color("#267F99"), dark: Color("#4EC9B0"))

        /// Everything between quotes, the quotes included.
        static let string = Color(light: Color("#A31515"), dark: Color("#CE9178"))

        /// `// like this`, to the end of the line.
        static let comment = Color(light: Color("#008000"), dark: Color("#6A9955"))

        /// Digits, and what follows them in one word.
        static let number = Color(light: Color("#098658"), dark: Color("#B5CEA8"))

        /// `@State`, `@StateClass` - the `@` and the name together.
        static let attribute = Color(light: Color("#0000FF"), dark: Color("#569CD6"))

        /// Everything else, which is most of it.
        static let plain = Palette.text
    }

    /// The words drawn as keywords.
    ///
    /// Only what the samples actually use, plus the neighbours somebody would
    /// notice missing. A word left out of this is drawn plain, which is a dull
    /// snippet rather than a wrong one.
    private static let keywords: Set<String> = [
        "as", "associatedtype", "async", "await", "break", "case", "catch",
        "class", "continue", "default", "defer", "deinit", "do", "else", "enum",
        "extension", "false", "fileprivate", "final", "for", "func", "get",
        "guard", "if", "import", "in", "indirect", "init", "inout", "internal",
        "is", "lazy", "let", "mutating", "nil", "nonisolated", "nonmutating",
        "open", "operator", "package", "private", "protocol", "public", "repeat",
        "required", "return", "self", "set", "some", "static", "struct",
        "subscript", "super", "switch", "throw", "throws", "true", "try",
        "typealias", "unowned", "var", "weak", "where", "while", "willSet",
        "didSet",
    ]

    /// The words C# owns - the interop listings' vocabulary, plus the
    /// neighbours somebody would notice missing.
    private static let csharpKeywords: Set<String> = [
        "abstract", "async", "await", "base", "bool", "break", "case", "catch",
        "class", "const", "continue", "default", "delegate", "do", "double",
        "else", "enum", "event", "false", "field", "finally", "for", "foreach",
        "get", "if", "in", "init", "int", "interface", "internal", "is",
        "lock", "nameof", "namespace", "new", "null", "object", "out",
        "override", "params", "private", "protected", "public", "readonly",
        "record", "ref", "return", "sealed", "set", "static", "string",
        "struct", "switch", "this", "throw", "true", "try", "typeof", "using",
        "var", "void", "when", "where", "while",
    ]

    /// The snippet, split into runs in the order it was written.
    static func runs(in source: String, language: CodeLanguage = .swift) -> [CodeRun] {
        let keywords = language == .swift ? Self.keywords : Self.csharpKeywords
        let characters = Array(source)
        var runs: [CodeRun] = []
        var plain = ""
        var index = 0

        /// Closes off whatever plain text has piled up.
        func flush() {
            guard !plain.isEmpty else { return }

            runs.append(CodeRun(text: plain, colour: Ink.plain))
            plain = ""
        }

        /// Emits one coloured run, after whatever came before it.
        func emit(_ range: Range<Int>, _ colour: Color) {
            flush()
            runs.append(CodeRun(text: String(characters[range]), colour: colour))
            index = range.upperBound
        }

        while index < characters.count {
            let character = characters[index]

            // A comment runs to the end of the line, so nothing inside it is
            // read as anything else. Checked first for that reason.
            if character == "/", next(characters, index) == "/" {
                var end = index
                while end < characters.count, characters[end] != "\n" { end += 1 }
                emit(index..<end, Ink.comment)
                continue
            }

            // A string literal, quotes included. A backslash takes the next
            // character with it, so `\"` does not end the string and neither
            // does the `"` of an interpolation written `\("…")`.
            if character == "\"" {
                var end = index + 1
                while end < characters.count, characters[end] != "\"" {
                    if characters[end] == "\\" { end += 1 }
                    end += 1
                }
                emit(index..<min(end + 1, characters.count), Ink.string)
                continue
            }

            // An attribute is the `@` and the name after it, drawn as one -
            // `@State` reads as a unit and is written as one.
            if character == "@" {
                var end = index + 1
                while end < characters.count, isWordCharacter(characters[end]) { end += 1 }
                emit(index..<end, Ink.attribute)
                continue
            }

            if isWordStart(character) {
                var end = index
                while end < characters.count, isWordCharacter(characters[end]) { end += 1 }

                let word = String(characters[index..<end])

                if keywords.contains(word) {
                    emit(index..<end, Ink.keyword)
                } else if isUppercaseAscii(word.first) {
                    emit(index..<end, Ink.type)
                } else {
                    plain += word
                    index = end
                }

                continue
            }

            if isDigit(character) {
                var end = index
                while end < characters.count, isWordCharacter(characters[end]) || characters[end] == "." {
                    end += 1
                }
                emit(index..<end, Ink.number)
                continue
            }

            plain.append(character)
            index += 1
        }

        flush()
        return runs
    }

    // MARK: - What counts as what

    private static func next(_ characters: [Character], _ index: Int) -> Character? {
        index + 1 < characters.count ? characters[index + 1] : nil
    }

    private static func isWordStart(_ character: Character) -> Bool {
        isLetterAscii(character) || character == "_"
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        isWordStart(character) || isDigit(character)
    }

    private static func isLetterAscii(_ character: Character) -> Bool {
        ("a"..."z").contains(character) || ("A"..."Z").contains(character)
    }

    private static func isUppercaseAscii(_ character: Character?) -> Bool {
        guard let character else { return false }

        return ("A"..."Z").contains(character)
    }

    private static func isDigit(_ character: Character) -> Bool {
        ("0"..."9").contains(character)
    }
}
