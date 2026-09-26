// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `RadioButtonContract` on a host: the user's choice is heard, and takes the check away from the others of its set.
@_spi(Host) public enum RadioButtonTests: ConformanceFamily {
    public static let name = "RadioButton"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aUsersChoiceTakesTheGroupsOtherCheckAway", covers: [
                Covered(RadioButtonContract.self), Covered(RadioButtonContract.isOn),
                Covered(RadioButtonContract.toggled), Covered(RadioButtonContract.groupName),
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
            ConformanceCase("setsOfDifferentNamesKeepTheirOwnChecks", covers: [
                Covered(RadioButtonContract.groupName), Covered(RadioButtonContract.isOn),
                Covered(RadioButtonContract.toggled),
            ]) { s in
                s.start {
                    VStack {
                        RadioButton("Small").groupName("size").isOn(true).id("small")
                        RadioButton("Large").groupName("size").id("large")
                        RadioButton("Red").groupName("colour").isOn(true).id("red")
                    }
                }

                try s.perform(.toggle, on: s.element("large"))
                try s.settle { try s.held(RadioButtonContract.isOn, on: s.element("small")) == false }
                s.expect(try s.held(RadioButtonContract.isOn, on: s.element("red")), true, "another set keeps its check")
            },
            Aspects.holds(RadioButtonContract.isOn, on: "RadioButton", false, then: true),
        ]
    }
}
