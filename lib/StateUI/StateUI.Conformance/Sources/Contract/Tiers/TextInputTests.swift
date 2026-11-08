// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextInputContract` on a host: each keystroke's words land on the state and are heard once, typing stops at the
/// bound, and the program's words are shown and heard by nobody - each case made for every element wearing the tier.
@_spi(Host) public enum TextInputTests: ConformanceFamily {
    public static let name = "TextInput"

    public static var cases: [ConformanceCase] { written.proving(TextInputContract.self) }

    /// Every case written for the contract: its own members, and a tier's its family takes up.
    @MainActor static var written: [ConformanceCase] {
        Specimens.wearing(TextInputContract.self).flatMap { element in
            [
                typed(element), bounded(element), writtenByTheProgram(element), readOnly(element), closed(element),
                filled(element),
                Aspects.holds(TextInputContract.maximumLength, on: element, 10, then: 3),
                Aspects.holds(PlaceholderElementContract.placeholder, on: element, "Name", then: "E-mail"),
                Aspects.holds(
                    TextInputContract.placeholderColor, on: element, .red, then: .blue,
                    with: [Write(PlaceholderElementContract.placeholder, "Name")]),
                Aspects.holds(TextInputContract.inputPurpose, on: element, .email, then: .url),
                Aspects.holds(TextInputContract.isReadOnly, on: element, false, then: true),
                Aspects.holds(TextInputContract.isSpellCheckEnabled, on: element, true, then: false),
                Aspects.holds(TextInputContract.isTextPredictionEnabled, on: element, true, then: false),
                Aspects.holds(TextInputContract.cursorPosition, on: element, 2, then: 4,
                              with: [Write(TextElementContract.text, "abcdefg")]),
                Aspects.holds(TextInputContract.selectionLength, on: element, 3, then: 1, with: [
                    Write(TextElementContract.text, "abcdefg"), Write(TextInputContract.cursorPosition, 2),
                ]),
            ] + (element == "TextEditor" ? [] : [standsAsWideAsItsWords(element)])
        }
    }

    /// A field nothing sizes stands at least as wide as its placeholder, and with none as twenty digits - the words
    /// beside it in a `Text` the measure - whatever the platform's own field asks for.
    /// Design: docs/design/host/layout.md#a-fields-own-width
    @MainActor
    static func standsAsWideAsItsWords(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAsWideAsItsWords", proves: [
            Covered(PlaceholderElementContract.placeholder, on: element),
        ], needs: [
            Covered(ViewContract.frameChanged, on: element), Covered(ViewContract.frameChanged, on: "Text"),
        ]) { s in
            for words in ["Search every note, folder and tag", nil] {
                let field = Received<[Double]>(), measure = Received<[Double]>()
                let said = words.map { [Write(PlaceholderElementContract.placeholder, $0)] as [any Worn] } ?? []
                s.start {
                    VStack {
                        HStack { ViewTests.reporting(element, field, said) }
                        HStack { ViewTests.reporting("Text", measure, [
                            Write(TextElementContract.text, words ?? String(repeating: "0", count: 20)),
                        ], id: "measure") }
                    }
                    .horizontalAlignment(.start)
                }

                s.settle { (field.values.last.map(FrameReport.size)?.first ?? 0) > 0 && !measure.values.isEmpty }
                let width = field.values.last.map(FrameReport.size)?.first ?? 0
                let least = measure.values.last.map(FrameReport.size)?.first ?? .infinity
                s.expect(width >= least, true, "\(width) wide beside words \(least) wide - \(words ?? "twenty digits")")
            }
        }
    }

    /// What a field is for reaches what its platform fills it in from: a name it keeps, a new password, a code it
    /// received - each as the tree changes it.
    @MainActor
    static func filled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).inputPurpose.reachesWhatThePlatformFillsIn", proves: [
            Covered(TextInputContract.inputPurpose, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let purpose = State(wrappedValue: InputPurpose.username)
            s.start {
                Specimens.page(element, [Write(TextInputContract.inputPurpose, purpose.wrappedValue)], beside: [
                    Button("Change").onClicked {
                        purpose.wrappedValue = purpose.wrappedValue == .username ? .newPassword : .oneTimeCode
                    }.id("change"),
                ])
            }
            let specimen = try s.specimen(element)
            s.expect(try s.filledIn(specimen), .username, "a name the platform keeps")

            for next in [InputPurpose.newPassword, .oneTimeCode] {
                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.filledIn(specimen) == next }
                s.expect(try s.filledIn(specimen), next, "what the tree changed it to")
            }
        }
    }

    /// A field the tree makes read only keeps the words it holds, whatever the user types.
    @MainActor
    static func readOnly(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aReadOnlyFieldKeepsItsWords", proves: [
            Covered(TextInputContract.isReadOnly, on: element),
        ], needs: [Covered(TextElementContract.text, on: element)]) { s in
            let words = State(wrappedValue: "kept")
            s.start { VStack { field(element, words, [Write(TextInputContract.isReadOnly, true)]) } }
            let view = try s.element("field")

            try? s.perform(.type("changed"), on: view)
            s.turn()
            s.expect(words.wrappedValue, "kept", "the state keeps its words")
            s.expect(try s.held(TextElementContract.text, on: view), "kept", "and so does the field")
        }
    }

    /// A field the tree closes to input stays closed whatever else of its behavior the tree writes.
    @MainActor
    static func closed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aClosedFieldStaysClosedAsItsBehaviorChanges", proves: [
            Covered(TextInputContract.isReadOnly, on: element),
        ], needs: [Covered(EnabledElementContract.isEnabled, on: element), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let words = State(wrappedValue: "kept")
            let readOnly = State(wrappedValue: true)
            s.start {
                VStack {
                    field(element, words, [
                        Write(EnabledElementContract.isEnabled, false),
                        Write(TextInputContract.isReadOnly, readOnly.wrappedValue),
                    ])
                    Button("Open").onClicked { readOnly.wrappedValue = false }.id("open")
                }
            }
            let view = try s.element("field")
            s.expect(try s.held(EnabledElementContract.isEnabled, on: view), false)

            try s.perform(.activate, on: s.element("open"))
            s.turn()
            s.expect(try s.held(EnabledElementContract.isEnabled, on: view), false, "no longer read only, still closed")
        }
    }

    /// Each keystroke's words reach the state, are heard once, and stay typed.
    @MainActor
    static func typed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).eachKeystrokeIsHeardAndStaysTyped", proves: [
            Covered(TextInputContract.textChanged, on: element),
        ], needs: [Covered(TextElementContract.text, on: element)]) { s in
            let words = State(wrappedValue: "")
            let heard = Received<String>()
            s.start { VStack { field(element, words, [Hear(TextInputContract.textChanged) { heard.values.append($0) }]) } }
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

    /// Typing stops at the most characters the tree allows - characters, however many units each is to the platform.
    @MainActor
    static func bounded(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).typingStopsAtTheMaximumLength", proves: [
            Covered(TextInputContract.maximumLength, on: element),
        ], needs: [Covered(TextElementContract.text, on: element)]) { s in
            let words = State(wrappedValue: "")
            s.start { VStack { field(element, words, [Write(TextInputContract.maximumLength, 3)]) } }
            let view = try s.element("field")

            try s.perform(.type("Ada"), on: view)
            s.settle { words.wrappedValue == "Ada" }
            try s.perform(.type("Adam"), on: view)
            s.turn()

            s.expect(words.wrappedValue, "Ada")
            s.expect(try s.held(TextElementContract.text, on: view), "Ada")

            try s.perform(.type("😀😀😀😀"), on: view)
            s.settle { words.wrappedValue == "😀😀😀" }
            s.expect(words.wrappedValue, "😀😀😀", "three characters, two units each to some platforms")
            s.expect(try s.held(TextElementContract.text, on: view), "😀😀😀")
        }
    }

    /// The program's words are shown, and not heard as typing.
    @MainActor
    static func writtenByTheProgram(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theProgramsWordsAreShownAndNotHeardAsTyping", proves: [
            Covered(TextInputContract.textChanged, on: element),
        ], needs: [Covered(TextElementContract.text, on: element), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let words = State(wrappedValue: "")
            let heard = Received<String>()
            s.start {
                VStack {
                    field(element, words, [Hear(TextInputContract.textChanged) { heard.values.append($0) }])
                    Button("Ada").onClicked { words.wrappedValue = "Ada" }.id("ada")
                }
            }
            let view = try s.element("field")

            try s.perform(.activate, on: s.element("ada"))
            try s.settle { try s.held(TextElementContract.text, on: view) == "Ada" }

            s.expect(try s.held(TextElementContract.text, on: view), "Ada")
            s.turn()
            s.expect(heard.values, [])
        }
    }

    /// A field of `element`'s kind over `words`, wearing `worn`, found by the id "field".
    @MainActor
    static func field(_ element: String, _ words: State<String>, _ worn: [any Worn] = []) -> AnyView {
        let dressing = Dressing(worn, id: "field")
        let field: any View = switch element {
        case "SearchField": dressing.dress(SearchField(words.projectedValue))
        case "TextEditor": dressing.dress(TextEditor(words.projectedValue))
        case "TextField": dressing.dress(TextField(words.projectedValue))
        default: Text("no field of \(element)")
        }
        return AnyView(field)
    }
}
