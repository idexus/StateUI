// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PickerContract` on a host: it offers its choices, those the tree changes too, and shows the one the tree made; the
/// user's choice lands on the state once, the program's is shown and comes back from nobody; its list opened and
/// closed by the user is heard, opened by the program heard only as the user closes it.
@_spi(Host) public enum PickerTests: ConformanceFamily {
    public static let name = "Picker"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Picker"),
            ConformanceCase("aPickerOffersItsChoicesAndShowsTheOneMade", proves: [
                Covered(PickerContract.options), Covered(PickerContract.selectedIndex),
            ]) { s in
                let size = State(wrappedValue: "M")
                s.start { VStack { Picker(["S", "M", "L"], selection: size.projectedValue).id("picker") } }
                let picker = try s.element("picker")

                s.expect(try s.held(PickerContract.options, on: picker), ["S", "M", "L"])
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 1)
            },
            ConformanceCase("aUsersChoiceLandsOnceAndTheProgramsComesBackFromNobody", proves: [
                Covered(PickerContract.selectedIndex),
                Covered(PickerContract.selectedIndexChanged),
            ], needs: [Covered(TextualElementContract.text, on: TextContract.self), Covered(ButtonContract.clicked)]) { s in
                let size = State(wrappedValue: "M")
                let written = Received<String>()
                let chosen = Proxy(get: { size.wrappedValue }, set: { written.values.append($0); size.wrappedValue = $0 })
                s.start {
                    VStack {
                        Text("size \(size.wrappedValue)").id("label")
                        Picker(["S", "M", "L"], selection: chosen).id("picker")
                        Button("Small").onClicked { size.wrappedValue = "S" }.id("small")
                    }
                }
                let picker = try s.element("picker")
                let label = try s.element("label")

                try s.perform(.choose(2), on: picker)
                try s.settle { try written.values == ["L"] && s.held(TextualElementContract.text, on: label) == "size L" }
                s.expect(written.values, ["L"])
                s.expect(try s.held(TextualElementContract.text, on: label), "size L", "the state took the user's choice")

                try s.perform(.activate, on: s.element("small"))
                try s.settle { try s.held(PickerContract.selectedIndex, on: picker) == 0 }
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 0, "the program's choice shown")
                s.expect(written.values, ["L"], "and come back from nobody")
            },
            ConformanceCase("theUsersChoiceStandsWhileTheTreeChangesItsTitle", proves: [
                Covered(PickerContract.placeholder),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let named = State(wrappedValue: false)
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(["S", "M", "L"], selection: size.projectedValue)
                            .placeholder(named.wrappedValue ? "Size" : "Pick").id("picker")
                        Button("Name").onClicked { named.wrappedValue = true }.id("change")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.choose(2), on: picker)
                try s.settle { try s.held(PickerContract.selectedIndex, on: picker) == 2 }
                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(PickerContract.placeholder, on: picker) == "Size" }
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 2, "the user's choice, not argued with")
            },
            ConformanceCase("choicesTheTreeChangesAreOffered", proves: [
                Covered(PickerContract.options),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let more = State(wrappedValue: false)
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(more.wrappedValue ? ["S", "M", "L", "XL"] : ["S", "M"], selection: size.projectedValue)
                            .id("picker")
                        Button("More").onClicked { more.wrappedValue = true }.id("change")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(PickerContract.options, on: picker) == ["S", "M", "L", "XL"] }
                s.expect(try s.held(PickerContract.options, on: picker), ["S", "M", "L", "XL"])
            },
            ConformanceCase("theListTheUserOpensAndClosesIsHeard", proves: [
                Covered(PickerContract.isOpen), Covered(PickerContract.opened), Covered(PickerContract.closed),
            ]) { s in
                let heard = Received<String>()
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(["S", "M", "L"], selection: size.projectedValue)
                            .onOpened { heard.values.append("opened") }
                            .onClosed { heard.values.append("closed") }
                            .id("picker")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.open, on: picker)
                s.settle { heard.values == ["opened"] }
                s.expect(try s.held(PickerContract.isOpen, on: picker), true)
                try s.perform(.close, on: picker)
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["opened", "closed"])
                s.expect(try s.held(PickerContract.isOpen, on: picker), false)
            },
            ConformanceCase("theListTheProgramOpensIsHeardOnlyAsTheUserClosesIt", proves: [
                Covered(PickerContract.isOpen), Covered(PickerContract.closed),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let showing = State(wrappedValue: false)
                let heard = Received<String>()
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(["S", "M", "L"], selection: size.projectedValue)
                            .isOpen(showing.wrappedValue)
                            .onOpened { heard.values.append("opened") }
                            .onClosed {
                                heard.values.append("closed")
                                showing.wrappedValue = false
                            }
                            .id("picker")
                        Button("Open").onClicked { showing.wrappedValue = true }.id("open")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.activate, on: s.element("open"))
                try s.settle { try s.held(PickerContract.isOpen, on: picker) == true }
                s.turn()
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
            offersItsValues(as: .segmented),
            takesTheUsersChoice(as: .segmented),
            offersItsValues(as: .radio),
            takesTheUsersChoice(as: .radio),
            Aspects.holds(PickerContract.placeholder, on: "Picker", "Size", then: "Color",
                          with: [Write(PickerContract.options, ["S", "M"])]),
        ]
    }

    /// A picker offered as `presentation` offers its values and shows the one chosen, and the one the program chooses.
    @MainActor static func offersItsValues(as presentation: PickerPresentation) -> ConformanceCase {
        ConformanceCase("\(presentation)OffersItsValuesAndShowsTheOneChosen", proves: [
            Covered(PickerContract.presentation), Covered(PickerContract.options), Covered(PickerContract.selectedIndex),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let size = State(wrappedValue: "M")
            s.start {
                VStack {
                    Picker(["S", "M", "L"], selection: size.projectedValue).presentation(presentation).id("picker")
                    Button("Small").onClicked { size.wrappedValue = "S" }.id("small")
                }
            }
            let picker = try s.element("picker")
            s.expect(try s.held(PickerContract.options, on: picker), ["S", "M", "L"])
            s.expect(try s.held(PickerContract.selectedIndex, on: picker), 1, "the value the state holds")

            try s.perform(.activate, on: s.element("small"))
            try s.settle { try s.held(PickerContract.selectedIndex, on: picker) == 0 }
            s.expect(try s.held(PickerContract.selectedIndex, on: picker), 0, "the program's choice shown")
        }
    }

    /// A picker offered as `presentation` takes the user's choice, which lands on the state as its value once.
    @MainActor static func takesTheUsersChoice(as presentation: PickerPresentation) -> ConformanceCase {
        ConformanceCase("\(presentation)TakesTheUsersChoice", proves: [
            Covered(PickerContract.presentation), Covered(PickerContract.selectedIndexChanged),
        ], needs: [Covered(TextualElementContract.text, on: TextContract.self)]) { s in
            let size = State(wrappedValue: "M")
            let written = Received<String>()
            let chosen = Proxy(get: { size.wrappedValue }, set: { written.values.append($0); size.wrappedValue = $0 })
            s.start {
                VStack {
                    Text("size \(size.wrappedValue)").id("label")
                    Picker(["S", "M", "L"], selection: chosen).presentation(presentation).id("picker")
                }
            }
            try s.perform(.choose(2), on: s.element("picker"))
            try s.settle { try s.held(TextualElementContract.text, on: s.element("label")) == "size L" }
            s.expect(try s.held(TextualElementContract.text, on: s.element("label")), "size L")
            s.expect(written.values, ["L"], "the user's choice landed once")
        }
    }
}
