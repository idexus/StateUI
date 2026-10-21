// Coloring a listing, in the language it is written in.
//
// A Text has one text color, so text in six colors is six spans - which is
// what `Text.spans` is for. This file turns a snippet into those runs.
//
// ASCII only, on purpose. Deciding what is a letter with `Character.isLetter`
// would work, but the whole question of which Unicode tables that reaches is one
// this repository would rather not open. Every keyword and every type name in a
// listing is ASCII, and anything else falls through as plain text, which is the
// right answer for it anyway.

import StateUI

/// One run of source that is all the same color.
struct CodeRun {
    /// The characters, exactly as they were written - whitespace included, so
    /// joining every run back up gives the snippet.
    let text: String

    /// What to draw it in.
    let color: Color
}

/// Splits a listing into colored runs.
///
/// Deliberately shallow: one pass, no parsing, no notion of scope. It reads
/// comments, string literals, attributes, keywords, capitalized names and
/// numbers, and calls everything else plain. That is enough to make a snippet
/// scannable and cannot be wrong about code it does not understand - the worst
/// it does is leave something uncolored.
enum CodeHighlight {
    /// The colors, each right on both themes. `Color(light:dark:)` picks its
    /// half as the run is built, so nothing here has to know which theme is on.
    private enum Ink {
        /// `let`, `func`, `if` - the words the language owns.
        static let keyword = Color(light: Color(hex: 0xAF00DB), dark: Color(hex: 0xC586C0))

        /// `Text`, `Basket` - anything starting with a capital.
        static let type = Color(light: Color(hex: 0x267F99), dark: Color(hex: 0x4EC9B0))

        /// Everything between quotes, the quotes included.
        static let string = Color(light: Color(hex: 0xA31515), dark: Color(hex: 0xCE9178))

        /// `// like this`, to the end of the line.
        static let comment = Color(light: Color(hex: 0x008000), dark: Color(hex: 0x6A9955))

        /// Digits, and what follows them in one word.
        static let number = Color(light: Color(hex: 0x098658), dark: Color(hex: 0xB5CEA8))

        /// `@State`, `@Environment` - the `@` and the name together.
        static let attribute = Color(light: Color(hex: 0x0000FF), dark: Color(hex: 0x569CD6))

        /// Everything else, which is most of it.
        static let plain = Palette.text
    }

    /// The snippet, split into runs in the order it was written.
    static func runs(in source: String, language: CodeLanguage = .swift) -> [CodeRun] {
        let keywords = language.keywords
        let characters = Array(source)
        var runs: [CodeRun] = []
        var plain = ""
        var index = 0

        /// Closes off whatever plain text has piled up.
        func flush() {
            guard !plain.isEmpty else { return }

            runs.append(CodeRun(text: plain, color: Ink.plain))
            plain = ""
        }

        /// Emits one colored run, after whatever came before it.
        func emit(_ range: Range<Int>, _ color: Color) {
            flush()
            runs.append(CodeRun(text: String(characters[range]), color: color))
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
