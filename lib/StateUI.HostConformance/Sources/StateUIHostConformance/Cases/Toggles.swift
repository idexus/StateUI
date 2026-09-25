// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a switch, a check box and a radio button do: the user's turn is heard once and lands on the state; the
/// program's is shown and heard by nobody; a radio button's set takes the others' check away.
@_spi(Host) public enum Toggles: ConformanceFamily {
    public static let name = "Toggles"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSwitchShowsWhatTheTreeSays", covers: [
                Covered(SwitchContract.isOn), Covered(SwitchContract.toggled), Covered(ButtonContract.clicked),
            ]) { s in
                let on = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        Switch(on.projectedValue).onToggled { heard.values.append($0) }.id("switch")
                        Button("On").onClicked { on.wrappedValue = true }.id("on")
                    }
                }
                let toggle = try s.element("switch")
                s.expect(try s.held(SwitchContract.isOn, on: toggle), false)

                try s.perform(.activate, on: s.element("on"))
                try s.settle { try s.held(SwitchContract.isOn, on: toggle) == true }

                s.expect(try s.held(SwitchContract.isOn, on: toggle), true, "the state the button wrote reached the switch")
                s.expect(heard.values, [], "and nobody heard it as the user's")
            },
            ConformanceCase("aUsersTurnReachesTheStateAndTheHandlerOnce", covers: [
                Covered(SwitchContract.isOn), Covered(SwitchContract.toggled),
                Covered(TextElementContract.text, on: LabelContract.self),
            ]) { s in
                let on = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        Label(on.wrappedValue ? "on" : "off").id("label")
                        Switch(on.projectedValue).onToggled { heard.values.append($0) }.id("switch")
                    }
                }
                let toggle = try s.element("switch")

                try s.perform(.toggle, on: toggle)
                s.settle { on.wrappedValue }

                s.expect(on.wrappedValue, true)
                s.expect(heard.values, [true])
                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "on")
                s.expect(try s.held(SwitchContract.isOn, on: toggle), true)
            },
            ConformanceCase("aUsersTickIsHeardAndTheProgramsIsNot", covers: [
                Covered(CheckBoxContract.isOn), Covered(CheckBoxContract.toggled), Covered(ButtonContract.clicked),
            ]) { s in
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
                try s.settle { try s.held(CheckBoxContract.isOn, on: box) == false }
                s.expect(try s.held(CheckBoxContract.isOn, on: box), false, "the state the button wrote reached the box")
                s.expect(heard.values, [true], "and nobody heard it as the user's")
            },
            ConformanceCase("aUsersChoiceTakesTheGroupsOtherCheckAway", covers: [
                Covered(RadioButtonContract.isOn), Covered(RadioButtonContract.toggled),
                Covered(RadioButtonContract.groupName),
            ]) { s in
                let choice = State(wrappedValue: "Small")
                let heard = Received<String>()
                s.start {
                    VStack {
                        ForEach(["Small", "Large"]) { name in
                            RadioButton(name)
                                .groupName("size")
                                .isOn(choice.wrappedValue == name)
                                .onToggled { chosen in
                                    heard.values.append("\(name) \(chosen)")
                                    if chosen { choice.wrappedValue = name }
                                }
                                .id(name)
                        }
                    }
                }
                let (small, large) = (try s.element("Small"), try s.element("Large"))

                try s.perform(.toggle, on: large)
                s.settle { choice.wrappedValue == "Large" }

                s.expect(heard.values, ["Small false", "Large true"], "the one checked before says it is off first")
                s.expect(choice.wrappedValue, "Large")
                s.expect([try s.held(RadioButtonContract.isOn, on: small), try s.held(RadioButtonContract.isOn, on: large)],
                         [false, true])
            },
            ConformanceCase("buttonsNamingNoSetAreOneWithTheirSiblings", covers: [
                Covered(RadioButtonContract.isOn), Covered(RadioButtonContract.toggled),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        ForEach(["A", "B"]) { name in
                            RadioButton(name).isOn(name == "A").onToggled { heard.values.append("\(name) \($0)") }
                                .id(name)
                        }
                        HStack {
                            RadioButton("C").isOn(true).onToggled { heard.values.append("C \($0)") }.id("C")
                        }
                    }
                }

                try s.perform(.toggle, on: s.element("B"))
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["A false", "B true"])
                s.expect(try ["A", "B", "C"].map { try s.held(RadioButtonContract.isOn, on: s.element($0)) },
                         [false, true, true], "C, beside no other, keeps its check")
            },
        ]
    }
}
