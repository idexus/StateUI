// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SubmitElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum SubmitElementTests: ConformanceFamily {
    public static let name = "SubmitElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("SearchField.theUsersSearchIsHeardAndTheProgramsIsNot", proves: [
                Covered(SubmitElementContract.submitted, on: SearchFieldContract.self),
            ], needs: [
                Covered(TextElementContract.text, on: SearchFieldContract.self),
                Covered(TextInputContract.textChanged, on: SearchFieldContract.self),
                Covered(ClickElementContract.clicked, on: ButtonContract.self),
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
            ConformanceCase("SearchField.eachSubmissionIsHeardOnce", proves: [Covered(SubmitElementContract.submitted, on: SearchFieldContract.self)]) { s in
                let heard = Received<String>()
                s.start {
                    VStack { SearchField(State(wrappedValue: "tea").projectedValue).onSubmitted { heard.values.append("s") }.id("search") }
                }
                let search = try s.element("search")

                try s.perform(.submit, on: search)
                s.settle { heard.values.count == 1 }
                try s.perform(.submit, on: search)
                s.settle { heard.values.count == 2 }
                s.turn()
                s.expect(heard.values, ["s", "s"], "each submission once")
            },
            Aspects.holds(SubmitElementContract.submitLabel, on: "SearchField", .search, then: .go),
            ConformanceCase("TextField.enterSubmitsAFieldOnce", proves: [Covered(SubmitElementContract.submitted, on: TextFieldContract.self)]) { s in
                let heard = Received<String>()
                s.start { VStack { TextField("").onSubmitted { heard.values.append("submitted") }.id("field") } }

                try s.perform(.submit, on: s.element("field"))
                s.settle { !heard.values.isEmpty }
                s.turn()

                s.expect(heard.values, ["submitted"])
            },
            Aspects.holds(SubmitElementContract.submitLabel, on: "TextField", .done, then: .send),
        ] + ["TextField", "SearchField"].map(TextFieldTests.handsTheKeyboardOn)
    }
}
