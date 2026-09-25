// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a picker does: it offers its choices and shows the one the tree made; the user's choice is heard once and
/// lands on the state, the program's is shown and heard by nobody.
@_spi(Host) public enum Choices: ConformanceFamily {
    public static let name = "Choices"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPickerOffersItsChoicesAndShowsTheOneMade", covers: [
                Covered(PickerContract.options), Covered(PickerContract.selectedIndex),
            ]) { s in
                s.start { VStack { Picker(["S", "M", "L"]).selectedIndex(State(wrappedValue: 1).projectedValue).id("picker") } }
                let picker = try s.element("picker")

                s.expect(try s.held(PickerContract.options, on: picker), ["S", "M", "L"])
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 1)
            },
            ConformanceCase("aUsersChoiceIsHeardAndTheProgramsIsNot", covers: [
                Covered(PickerContract.selectedIndex), Covered(PickerContract.selectedIndexChanged),
                Covered(TextElementContract.text, on: LabelContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                let size = State(wrappedValue: 1)
                let heard = Received<String>()
                s.start {
                    VStack {
                        Label("size \(size.wrappedValue)").id("label")
                        Picker(["S", "M", "L"])
                            .selectedIndex(size.projectedValue)
                            .onSelectedIndexChanged { heard.values.append("chose \($0)") }
                            .id("picker")
                        Button("Small").onClicked { size.wrappedValue = 0 }.id("small")
                    }
                }
                let picker = try s.element("picker")
                let label = try s.element("label")

                try s.perform(.choose(2), on: picker)
                try s.settle { try heard.values == ["chose 2"] && s.held(TextElementContract.text, on: label) == "size 2" }
                s.expect(heard.values, ["chose 2"])
                s.expect(try s.held(TextElementContract.text, on: label), "size 2", "the state took the user's choice")

                try s.perform(.activate, on: s.element("small"))
                try s.settle { try s.held(PickerContract.selectedIndex, on: picker) == 0 }
                s.expect(try s.held(PickerContract.selectedIndex, on: picker), 0, "the program's choice shown")
                s.expect(heard.values, ["chose 2"], "and heard by nobody")
            },
        ]
    }
}
