// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PickerContract` on a host: it offers its choices and shows the one the tree made; the user's choice is heard once
/// and lands on the state, the program's is shown and heard by nobody.
@_spi(Host) public enum PickerTests: ConformanceFamily {
    public static let name = "Picker"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPickerOffersItsChoicesAndShowsTheOneMade", covers: [
                Covered(PickerContract.self), Covered(PickerContract.options), Covered(PickerContract.selectedIndex),
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
            ConformanceCase("choicesTheTreeChangesAreOffered", covers: [
                Covered(PickerContract.options), Covered(ButtonContract.clicked),
            ]) { s in
                let more = State(wrappedValue: false)
                s.start {
                    VStack {
                        Picker(more.wrappedValue ? ["S", "M", "L", "XL"] : ["S", "M"]).id("picker")
                        Button("More").onClicked { more.wrappedValue = true }.id("change")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(PickerContract.options, on: picker) == ["S", "M", "L", "XL"] }
                s.expect(try s.held(PickerContract.options, on: picker), ["S", "M", "L", "XL"])
            },
            ConformanceCase("theListTheUserOpensAndClosesIsHeard", covers: [
                Covered(PickerContract.isOpen), Covered(PickerContract.opened), Covered(PickerContract.closed),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Picker(["S", "M", "L"])
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
            ConformanceCase("theListTheProgramOpensIsHeardOnlyAsTheUserClosesIt", covers: [
                Covered(PickerContract.isOpen), Covered(PickerContract.closed), Covered(ButtonContract.clicked),
            ]) { s in
                let showing = State(wrappedValue: false)
                let heard = Received<String>()
                s.start {
                    VStack {
                        Picker(["S", "M", "L"])
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
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
            Aspects.holds(PickerContract.title, on: "Picker", "Size", then: "Colour",
                          with: [Write(PickerContract.options, ["S", "M"])]),
        ]
    }
}
