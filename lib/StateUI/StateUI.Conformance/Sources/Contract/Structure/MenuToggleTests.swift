// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuToggleContract` on a host: a setting's entry stands checked as the tree says, and choosing it turns its state
/// over.
@_spi(Host) public enum MenuToggleTests: ConformanceFamily {
    public static let name = "MenuToggle"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anEntryStandsCheckedAsTheTreeSays", proves: [
                Covered(MenuToggleContract.self), Covered(MenuToggleContract.isOn),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let on = State(wrappedValue: false)
                s.start {
                    VStack {
                        Text("Row").contextMenu {
                            MenuToggle("Ruler", isOn: on.wrappedValue).id("ruler")
                        }.id("row")
                        Button("Change").onClicked { on.wrappedValue.toggle() }.id("change")
                    }
                }
                let ruler = try s.element("ruler")
                s.expect(try s.held(MenuToggleContract.isOn, on: ruler), false, "made unchecked")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(MenuToggleContract.isOn, on: ruler) == true }
                s.expect(try s.held(MenuToggleContract.isOn, on: ruler), true, "checked as the tree changed it")
            },
            ConformanceCase("anEntryChosenTurnsItsStateOver", proves: [
                Covered(MenuToggleContract.toggled), Covered(MenuToggleContract.isOn),
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
                try s.settle { try s.held(MenuToggleContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(MenuToggleContract.isOn, on: s.element("ruler")), true, "and the entry stands checked")

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { !on.wrappedValue }
                s.expect(on.wrappedValue, false, "chosen checked, the state turns off")
                s.expect(heard.values, [true, false], "each turn heard with the way it turned")
            },
        ]
    }
}
