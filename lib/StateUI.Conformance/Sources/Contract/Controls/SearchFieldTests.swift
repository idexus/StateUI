// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SearchFieldContract` on a host: the user's search is heard as typed and as submitted; the program's words are
/// shown and heard by nobody.
@_spi(Host) public enum SearchFieldTests: ConformanceFamily {
    public static let name = "SearchField"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theUsersSearchIsHeardAndTheProgramsIsNot", covers: [
                Covered(SearchFieldContract.self), Covered(TextElementContract.text, on: SearchFieldContract.self),
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
            ConformanceCase("eachSubmissionIsHeardOnce", covers: [Covered(SearchFieldContract.submitted)]) { s in
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
            Aspects.holds(SearchFieldContract.returnKey, on: "SearchField", .search, then: .go),
        ]
    }
}
