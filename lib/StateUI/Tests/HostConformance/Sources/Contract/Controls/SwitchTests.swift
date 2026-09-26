// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `SwitchContract` on a host: the user's turn is heard once and lands on the state; the program's is shown and heard
/// by nobody.
@_spi(Host) public enum SwitchTests: ConformanceFamily {
    public static let name = "Switch"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSwitchShowsWhatTheTreeSays", covers: [
                Covered(SwitchContract.self), Covered(SwitchContract.isOn), Covered(SwitchContract.toggled),
                Covered(ButtonContract.clicked),
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
            ConformanceCase("aUsersTurnBackIsHeardToo", covers: [
                Covered(SwitchContract.isOn), Covered(SwitchContract.toggled),
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
                s.expect(try s.held(SwitchContract.isOn, on: toggle), true)
            },
            Aspects.holds(SwitchContract.isOn, on: "Switch", false, then: true),
        ]
    }
}
