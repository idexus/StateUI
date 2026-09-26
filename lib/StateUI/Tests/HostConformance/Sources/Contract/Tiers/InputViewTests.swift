// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `InputViewContract` on a host: each keystroke's words land on the state and are heard once, typing stops at the
/// bound, and the program's words are shown and heard by nobody - each case made for every element wearing the tier.
@_spi(Host) public enum InputViewTests: ConformanceFamily {
    public static let name = "InputView"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(InputViewContract.self).flatMap { element in
            [
                typed(element), bounded(element), written(element), readOnly(element),
                Aspects.holds(InputViewContract.maximumLength, on: element, 10, then: 3),
                Aspects.holds(InputViewContract.placeholder, on: element, "Name", then: "E-mail"),
                Aspects.holds(InputViewContract.placeholderColor, on: element, .red, then: .blue),
                Aspects.holds(InputViewContract.inputPurpose, on: element, .email, then: .url),
                Aspects.holds(InputViewContract.isReadOnly, on: element, false, then: true),
                Aspects.holds(InputViewContract.isSpellCheckEnabled, on: element, true, then: false),
                Aspects.holds(InputViewContract.isTextPredictionEnabled, on: element, true, then: false),
                Aspects.holds(InputViewContract.cursorPosition, on: element, 2, then: 4,
                              with: [Write(TextElementContract.text, "abcdefg")]),
                Aspects.holds(InputViewContract.selectionLength, on: element, 3, then: 1, with: [
                    Write(TextElementContract.text, "abcdefg"), Write(InputViewContract.cursorPosition, 2),
                ]),
            ]
        }
    }

    /// A field the tree makes read only keeps the words it holds, whatever the user types.
    static func readOnly(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aReadOnlyFieldKeepsItsWords", covers: [
            Covered(InputViewContract.isReadOnly, on: element), Covered(TextElementContract.text, on: element),
        ]) { s in
            let words = State(wrappedValue: "kept")
            s.start { VStack { field(element, words, [Write(InputViewContract.isReadOnly, true)]) } }
            let view = try s.element("field")

            try? s.perform(.type("changed"), on: view)
            s.turn()
            s.expect(words.wrappedValue, "kept", "the state keeps its words")
            s.expect(try s.held(TextElementContract.text, on: view), "kept", "and so does the field")
        }
    }

    /// Each keystroke's words reach the state, are heard once, and stay typed.
    static func typed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).eachKeystrokeIsHeardAndStaysTyped", covers: [
            Covered(InputViewContract.textChanged, on: element), Covered(TextElementContract.text, on: element),
        ]) { s in
            let words = State(wrappedValue: "")
            let heard = Received<String>()
            s.start { VStack { field(element, words, [Hear(InputViewContract.textChanged) { heard.values.append($0) }]) } }
            let view = try s.element("field")

            for typed in ["A", "Ad", "Ada"] {
                try s.perform(.type(typed), on: view)
                s.settle { words.wrappedValue == typed }
            }

            s.expect(words.wrappedValue, "Ada")
            s.expect(heard.values, ["A", "Ad", "Ada"], "each keystroke heard once")
            s.expect(try s.held(TextElementContract.text, on: view), "Ada")
        }
    }

    /// Typing stops at the most characters the tree allows.
    static func bounded(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).typingStopsAtTheMaximumLength", covers: [
            Covered(InputViewContract.maximumLength, on: element), Covered(TextElementContract.text, on: element),
        ]) { s in
            let words = State(wrappedValue: "")
            s.start { VStack { field(element, words, [Write(InputViewContract.maximumLength, 3)]) } }
            let view = try s.element("field")

            try s.perform(.type("Ada"), on: view)
            s.settle { words.wrappedValue == "Ada" }
            try s.perform(.type("Adam"), on: view)
            s.turn()

            s.expect(words.wrappedValue, "Ada")
            s.expect(try s.held(TextElementContract.text, on: view), "Ada")
        }
    }

    /// The program's words are shown, and not heard as typing.
    static func written(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theProgramsWordsAreShownAndNotHeardAsTyping", covers: [
            Covered(InputViewContract.textChanged, on: element), Covered(TextElementContract.text, on: element),
            Covered(ButtonContract.clicked),
        ]) { s in
            let words = State(wrappedValue: "")
            let heard = Received<String>()
            s.start {
                VStack {
                    field(element, words, [Hear(InputViewContract.textChanged) { heard.values.append($0) }])
                    Button("Ada").onClicked { words.wrappedValue = "Ada" }.id("ada")
                }
            }
            let view = try s.element("field")

            try s.perform(.activate, on: s.element("ada"))
            try s.settle { try s.held(TextElementContract.text, on: view) == "Ada" }

            s.expect(try s.held(TextElementContract.text, on: view), "Ada")
            s.expect(heard.values, [])
        }
    }

    /// A field of `element`'s kind over `words`, wearing `worn`, found by the id "field".
    static func field(_ element: String, _ words: State<String>, _ worn: [any Worn] = []) -> any View {
        let dressing = Dressing(worn, id: "field")
        switch element {
        case "SearchField": return dressing.dress(SearchField(words.projectedValue))
        case "TextEditor": return dressing.dress(TextEditor(words.projectedValue))
        case "TextField": return dressing.dress(TextField(words.projectedValue))
        default: return Label("no field of \(element)")
        }
    }
}
