// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToggleElementContract` on a host: the user's turn is heard once and lands on the state; the program's is shown
/// and heard by nobody - on each element wearing the tier, in the place it stands.
@_spi(Host) public enum ToggleElementTests: ConformanceFamily {
    public static let name = "ToggleElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("CheckBox.aUsersTickIsHeardAndTheProgramsIsNot", proves: [
                Covered(ToggleElementContract.isOn, on: CheckBoxContract.self),
                Covered(ToggleElementContract.toggled, on: CheckBoxContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let ticked = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        CheckBox(ticked.projectedValue).onToggled { heard.values.append($0) }.id("box")
                        Button("Untick").onClicked { ticked.wrappedValue = false }.id("untick")
                    }
                }
                let box = try s.element("box")

                try s.perform(.toggle, on: box)
                s.settle { ticked.wrappedValue }
                s.expect(ticked.wrappedValue, true)
                s.expect(heard.values, [true])

                try s.perform(.activate, on: s.element("untick"))
                try s.settle { try s.held(ToggleElementContract.isOn, on: box) == false }
                s.expect(try s.held(ToggleElementContract.isOn, on: box), false, "the state the button wrote reached the box")
                s.expect(heard.values, [true], "and nobody heard it as the user's")
            },
            ConformanceCase("CheckBox.aUsersSecondTickTakesItsTickAway", proves: [
                Covered(ToggleElementContract.isOn, on: CheckBoxContract.self),
                Covered(ToggleElementContract.toggled, on: CheckBoxContract.self),
            ]) { s in
                let ticked = State(wrappedValue: true)
                let heard = Received<Bool>()
                s.start { VStack { CheckBox(ticked.projectedValue).onToggled { heard.values.append($0) }.id("box") } }
                let box = try s.element("box")
                s.expect(try s.held(ToggleElementContract.isOn, on: box), true, "ticked as the tree made it")

                try s.perform(.toggle, on: box)
                s.settle { !ticked.wrappedValue }
                s.expect(heard.values, [false])
                s.expect(try s.held(ToggleElementContract.isOn, on: box), false)
            },
            Aspects.holds(ToggleElementContract.isOn, on: "CheckBox", false, then: true),
            ConformanceCase("Switch.aSwitchShowsWhatTheTreeSays", proves: [
                Covered(ToggleElementContract.isOn, on: SwitchContract.self),
                Covered(ToggleElementContract.toggled, on: SwitchContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let on = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        Switch(on.projectedValue).onToggled { heard.values.append($0) }.id("switch")
                        Button("On").onClicked { on.wrappedValue = true }.id("on")
                    }
                }
                let toggle = try s.element("switch")
                s.expect(try s.held(ToggleElementContract.isOn, on: toggle), false)

                try s.perform(.activate, on: s.element("on"))
                try s.settle { try s.held(ToggleElementContract.isOn, on: toggle) == true }

                s.expect(try s.held(ToggleElementContract.isOn, on: toggle), true, "the state the button wrote reached the switch")
                s.turn()
                s.expect(heard.values, [], "and nobody heard it as the user's")
            },
            ConformanceCase("Switch.aUsersTurnReachesTheStateAndTheHandlerOnce", proves: [
                Covered(ToggleElementContract.isOn, on: SwitchContract.self),
                Covered(ToggleElementContract.toggled, on: SwitchContract.self),
            ], needs: [Covered(TextElementContract.text, on: TextContract.self)]) { s in
                let on = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        Text(on.wrappedValue ? "on" : "off").id("label")
                        Switch(on.projectedValue).onToggled { heard.values.append($0) }.id("switch")
                    }
                }
                let toggle = try s.element("switch")

                try s.perform(.toggle, on: toggle)
                s.settle { on.wrappedValue }

                s.expect(on.wrappedValue, true)
                s.expect(heard.values, [true])
                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "on")
                s.expect(try s.held(ToggleElementContract.isOn, on: toggle), true)
            },
            ConformanceCase("Switch.aUsersTurnBackIsHeardToo", proves: [
                Covered(ToggleElementContract.isOn, on: SwitchContract.self),
                Covered(ToggleElementContract.toggled, on: SwitchContract.self),
            ]) { s in
                let on = State(wrappedValue: true)
                let heard = Received<Bool>()
                s.start { VStack { Switch(on.projectedValue).onToggled { heard.values.append($0) }.id("switch") } }
                let toggle = try s.element("switch")

                try s.perform(.toggle, on: toggle)
                s.settle { !on.wrappedValue }
                try s.perform(.toggle, on: toggle)
                s.settle { on.wrappedValue }

                s.expect(heard.values, [false, true], "each turn heard once, either way")
                s.expect(try s.held(ToggleElementContract.isOn, on: toggle), true)
            },
            Aspects.holds(ToggleElementContract.isOn, on: "Switch", false, then: true),
            ConformanceCase("MenuToggle.anEntryChosenTurnsItsStateOver", proves: [
                Covered(ToggleElementContract.toggled, on: MenuToggleContract.self),
                Covered(ToggleElementContract.isOn, on: MenuToggleContract.self),
            ]) { s in
                let on = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    Text("Row").contextMenu {
                        MenuToggle("Ruler", isOn: on.projectedValue).onToggled { heard.values.append($0) }.id("ruler")
                    }.id("row")
                }

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { on.wrappedValue }
                s.expect(on.wrappedValue, true, "chosen unchecked, the state turns on")
                try s.settle { try s.held(ToggleElementContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(ToggleElementContract.isOn, on: s.element("ruler")), true, "and the entry stands checked")

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { !on.wrappedValue }
                s.expect(on.wrappedValue, false, "chosen checked, the state turns off")
                s.expect(heard.values, [true, false], "each turn heard with the way it turned")
            },
            ConformanceCase("ToolbarToggle.anItemChosenTurnsItsStateOver", proves: [
                Covered(ToggleElementContract.toggled, on: ToolbarToggleContract.self),
                Covered(ToggleElementContract.isOn, on: ToolbarToggleContract.self),
            ]) { s in
                let ruler = State(wrappedValue: false)
                let grid = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    ToolbarToggleTests.page {
                        [
                            ToolbarToggle("Ruler", isOn: ruler.projectedValue).onToggled { heard.values.append($0) }
                                .id("ruler"),
                            ToolbarToggle("Grid", isOn: grid.projectedValue).placement(at: .overflow).id("grid"),
                        ]
                    }
                }

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { ruler.wrappedValue }
                s.expect(ruler.wrappedValue, true, "chosen off, the state turns on")
                try s.settle { try s.held(ToggleElementContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(ToggleElementContract.isOn, on: s.element("ruler")), true, "and the item stands on")

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { !ruler.wrappedValue }
                s.expect(ruler.wrappedValue, false, "chosen on, the state turns off")
                s.expect(heard.values, [true, false], "each turn heard with the way it turned")

                try s.perform(.activate, on: s.element("grid"))
                s.settle { grid.wrappedValue }
                s.expect(grid.wrappedValue, true, "one in the overflow turns alike")
            },
        ]
    }
}
