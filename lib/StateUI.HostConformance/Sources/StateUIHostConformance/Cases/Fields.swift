// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a text field, a search field and an editor do: each keystroke's words land on the state and stay typed,
/// typing stops at the bound, Enter submits once, and the program's words are shown and heard by nobody.
@_spi(Host) public enum Fields: ConformanceFamily {
    public static let name = "Fields"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("eachKeystrokeReachesTheStateAndStaysTyped", covers: [
                Covered(TextElementContract.text, on: TextFieldContract.self),
                Covered(InputViewContract.textChanged, on: TextFieldContract.self),
                Covered(TextElementContract.text, on: LabelContract.self),
            ]) { s in
                let name = State(wrappedValue: "")
                s.start { greeting(name) }
                let field = try s.element("field")

                for typed in ["A", "Ad", "Ada"] {
                    try s.perform(.type(typed), on: field)
                    s.settle { name.wrappedValue == typed }
                }

                s.expect(name.wrappedValue, "Ada")
                s.expect(try s.held(TextElementContract.text, on: field), "Ada")
                s.expect(try s.held(TextElementContract.text, on: s.element("greeting")), "Hello, Ada!")
            },
            ConformanceCase("typingStopsAtTheMaximumLength", covers: [
                Covered(TextElementContract.text, on: TextFieldContract.self),
                Covered(InputViewContract.maximumLength, on: TextFieldContract.self),
            ]) { s in
                let name = State(wrappedValue: "")
                s.start { greeting(name, maximumLength: 3) }
                let field = try s.element("field")

                try s.perform(.type("Ada"), on: field)
                s.settle { name.wrappedValue == "Ada" }
                try s.perform(.type("Adam"), on: field)
                s.turn()

                s.expect(name.wrappedValue, "Ada")
                s.expect(try s.held(TextElementContract.text, on: field), "Ada")
            },
            ConformanceCase("aStateWriteShowsTheWordsAndIsNotHeardAsTyping", covers: [
                Covered(TextElementContract.text, on: TextFieldContract.self),
                Covered(InputViewContract.textChanged, on: TextFieldContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                let name = State(wrappedValue: "")
                let typed = Received<String>()
                s.start {
                    VStack {
                        TextField(name.projectedValue).onTextChanged { typed.values.append($0) }.id("field")
                        Button("Ada").onClicked { name.wrappedValue = "Ada" }.id("ada")
                    }
                }
                let field = try s.element("field")

                try s.perform(.activate, on: s.element("ada"))
                try s.settle { try s.held(TextElementContract.text, on: field) == "Ada" }

                s.expect(try s.held(TextElementContract.text, on: field), "Ada")
                s.expect(typed.values, [])
            },
            ConformanceCase("enterSubmitsAFieldOnce", covers: [Covered(TextFieldContract.submitted)]) { s in
                let heard = Received<String>()
                s.start { VStack { TextField("").onSubmitted { heard.values.append("submitted") }.id("field") } }

                try s.perform(.submit, on: s.element("field"))
                s.settle { !heard.values.isEmpty }
                s.turn()

                s.expect(heard.values, ["submitted"])
            },
            ConformanceCase("theUsersSearchIsHeardAndTheProgramsIsNot", covers: [
                Covered(TextElementContract.text, on: SearchFieldContract.self),
                Covered(InputViewContract.textChanged, on: SearchFieldContract.self),
                Covered(SearchFieldContract.submitted), Covered(ButtonContract.clicked),
            ]) { s in
                let query = State(wrappedValue: "")
                let heard = Received<String>()
                s.start {
                    VStack {
                        SearchField(query.projectedValue)
                            .onTextChanged { heard.values.append($0) }
                            .onSubmitted { heard.values.append("submitted") }
                            .id("search")
                        Button("Tea").onClicked { query.wrappedValue = "tea" }.id("tea")
                    }
                }
                let search = try s.element("search")

                try s.perform(.type("coffee"), on: search)
                try s.perform(.submit, on: search)
                s.settle { query.wrappedValue == "coffee" && heard.values.count == 2 }
                s.expect(heard.values, ["coffee", "submitted"])

                try s.perform(.activate, on: s.element("tea"))
                try s.settle { try s.held(TextElementContract.text, on: search) == "tea" }
                s.expect(try s.held(TextElementContract.text, on: search), "tea")
                s.expect(heard.values, ["coffee", "submitted"], "the program's words heard by nobody")
            },
            ConformanceCase("anEditorsWordsAreHeardWithinTheirBound", covers: [
                Covered(TextElementContract.text, on: TextEditorContract.self),
                Covered(InputViewContract.textChanged, on: TextEditorContract.self),
                Covered(InputViewContract.maximumLength, on: TextEditorContract.self),
            ]) { s in
                let words = State(wrappedValue: "")
                let heard = Received<String>()
                s.start {
                    VStack {
                        TextEditor(words.projectedValue).maximumLength(5).onTextChanged { heard.values.append($0) }
                            .id("editor")
                    }
                }
                let editor = try s.element("editor")

                try s.perform(.type("one\ntwo"), on: editor)
                s.settle { !heard.values.isEmpty }
                s.turn()

                s.expect(words.wrappedValue, "one\nt")
                s.expect(try s.held(TextElementContract.text, on: editor), "one\nt")
                s.expect(heard.values, ["one\nt"], "heard once, as the bound left the words")
            },
        ]
    }

    /// A greeting over a field, as HelloWorld's page has it.
    private static func greeting(_ name: State<String>, maximumLength: Int = 40) -> any Page {
        VStack {
            Label(name.wrappedValue.isEmpty ? "Hello!" : "Hello, \(name.wrappedValue)!").id("greeting")
            TextField(name.projectedValue).placeholder("Type your name").maximumLength(maximumLength).id("field")
        }
    }
}
