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
            ], needs: [Covered(TextElementContract.text, on: TextContract.self), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let size = State(wrappedValue: "M")
                let written = Received<String>()
                let sizes = ["S", "M", "L"]
                s.start {
                    VStack {
                        Text("size \(size.wrappedValue)").id("label")
                        Picker(sizes, selection: size.projectedValue)
                            .onSelectionChanged { written.values.append(size.wrappedValue) }
                            .id("picker")
                        Button("Small").onClicked { size.wrappedValue = "S" }.id("small")
                    }
                }
                let picker = try s.element("picker")
                let label = try s.element("label")

                try s.perform(.choose(2), on: picker)
                try s.settle { try written.values == ["L"] && s.held(TextElementContract.text, on: label) == "size L" }
                s.expect(written.values, ["L"])
                s.expect(try s.held(TextElementContract.text, on: label), "size L", "the state took the user's choice")

                try s.perform(.activate, on: s.element("small"))
                try s.settle { try s.held(PickerContract.selectedIndex, on: picker) == 0 }
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 0, "the program's choice shown")
                s.expect(written.values, ["L"], "and come back from nobody")
            },
            ConformanceCase("choicesTheTreeChangesAreOffered", proves: [
                Covered(PickerContract.options),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
            offersItsValues(as: .segmented),
            takesTheUsersChoice(as: .segmented),
            offersItsValues(as: .radio),
            takesTheUsersChoice(as: .radio),
        ] + PickerPresentation.allCases.map(keepsItsValue(as:))
    }

    /// A picker offered as `presentation` whose values change their order keeps the value it holds, at its new
    /// place, and tells nobody.
    @MainActor static func keepsItsValue(as presentation: PickerPresentation) -> ConformanceCase {
        ConformanceCase("\(presentation)KeepsItsValueAsItsValuesChangeTheirOrder", proves: [
            Covered(PickerContract.presentation), Covered(PickerContract.options), Covered(PickerContract.selectedIndex),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let reversed = State(wrappedValue: false)
            let size = State(wrappedValue: "S")
            let heard = Received<String>()
            s.start {
                VStack {
                    Picker(reversed.wrappedValue ? ["L", "M", "S"] : ["S", "M", "L"], selection: size.projectedValue)
                        .onSelectionChanged { heard.values.append(size.wrappedValue) }
                        .presentation(presentation)
                        .id("picker")
                    Button("Reverse").onClicked { reversed.wrappedValue = true }.id("reverse")
                }
            }
            let picker = try s.element("picker")
            s.expect(try s.held(PickerContract.selectedIndex, on: picker), 0)

            try s.perform(.activate, on: s.element("reverse"))
            try s.settle {
                try s.held(PickerContract.options, on: picker) == ["L", "M", "S"]
                    && s.held(PickerContract.selectedIndex, on: picker) == 2
            }
            s.expect(try s.held(PickerContract.options, on: picker), ["L", "M", "S"])
            s.expect(try s.held(PickerContract.selectedIndex, on: picker), 2, "the same value at its new place")
            s.expect(size.wrappedValue, "S", "the state holds it still")
            s.turn()
            s.expect(heard.values, [], "and nobody heard a choice")
        }
    }

    /// A picker offered as `presentation` offers its values and shows the one chosen, and the one the program chooses.
    @MainActor static func offersItsValues(as presentation: PickerPresentation) -> ConformanceCase {
        ConformanceCase("\(presentation)OffersItsValuesAndShowsTheOneChosen", proves: [
            Covered(PickerContract.presentation), Covered(PickerContract.options), Covered(PickerContract.selectedIndex),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
        ], needs: [Covered(TextElementContract.text, on: TextContract.self)]) { s in
            let size = State(wrappedValue: "M")
            let written = Received<String>()
            let sizes = ["S", "M", "L"]
            s.start {
                VStack {
                    Text("size \(size.wrappedValue)").id("label")
                    Picker(sizes, selection: size.projectedValue)
                        .onSelectionChanged { written.values.append(size.wrappedValue) }
                        .presentation(presentation)
                        .id("picker")
                }
            }
            try s.perform(.choose(2), on: s.element("picker"))
            try s.settle { try s.held(TextElementContract.text, on: s.element("label")) == "size L" }
            s.expect(try s.held(TextElementContract.text, on: s.element("label")), "size L")
            s.expect(written.values, ["L"], "the user's choice landed once")
        }
    }
}
