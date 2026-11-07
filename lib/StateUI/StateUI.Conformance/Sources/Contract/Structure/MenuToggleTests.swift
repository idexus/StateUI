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
                Covered(MenuToggleContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                s.expect(try s.held(ToggleElementContract.isOn, on: ruler), false, "made unchecked")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ToggleElementContract.isOn, on: ruler) == true }
                s.expect(try s.held(ToggleElementContract.isOn, on: ruler), true, "checked as the tree changed it")
            },

        ]
    }
}
