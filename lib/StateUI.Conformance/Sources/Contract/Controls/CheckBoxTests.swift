// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `CheckBoxContract` on a host: the user's tick is heard once and lands on the state; the program's is shown and
/// heard by nobody.
@_spi(Host) public enum CheckBoxTests: ConformanceFamily {
    public static let name = "CheckBox"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aUsersTickIsHeardAndTheProgramsIsNot", covers: [
                Covered(CheckBoxContract.self), Covered(CheckBoxContract.isOn), Covered(CheckBoxContract.toggled),
                Covered(ButtonContract.clicked),
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
            ConformanceCase("aUsersSecondTickTakesItsTickAway", covers: [
                Covered(CheckBoxContract.isOn), Covered(CheckBoxContract.toggled),
            ]) { s in
                let ticked = State(wrappedValue: true)
                let heard = Received<Bool>()
                s.start { VStack { CheckBox(ticked.projectedValue).onToggled { heard.values.append($0) }.id("box") } }
                let box = try s.element("box")
                s.expect(try s.held(CheckBoxContract.isOn, on: box), true, "ticked as the tree made it")

                try s.perform(.toggle, on: box)
                s.settle { !ticked.wrappedValue }
                s.expect(heard.values, [false])
                s.expect(try s.held(CheckBoxContract.isOn, on: box), false)
            },
            Aspects.holds(CheckBoxContract.isOn, on: "CheckBox", false, then: true),
        ]
    }
}
