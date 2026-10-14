// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuItemContract` on a host: an item chosen from a view's menu runs its own handler, one in a submenu too; an
/// item stands checked as the tree says, and choosing a checked one turns its state over.
@_spi(Host) public enum MenuItemTests: ConformanceFamily {
    public static let name = "MenuItem"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anItemChosenRunsItsOwnHandler", proves: [
                Covered(MenuItemContract.self), Covered(MenuItemElementContract.clicked, on: "MenuItem"),
            ]) { s in
                let heard = Received<String>()
                s.start { MenuPage(heard: heard) }

                try s.perform(.activate, on: s.element("share Mail"))
                s.settle { heard.values == ["share Mail"] }
                try s.perform(.activate, on: s.element("copy"))
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["share Mail", "copy"], "each item its own handler, a submenu's too")
            },
            ConformanceCase("anItemStandsCheckedAsTheTreeSays", proves: [
                Covered(MenuItemContract.isOn, on: "MenuItem"),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let on = State(wrappedValue: false)
                s.start {
                    VStack {
                        Text("Row").contextMenu {
                            MenuItem("Ruler").isOn(on.wrappedValue).id("ruler")
                        }.id("row")
                        Button("Change").onClicked { on.wrappedValue.toggle() }.id("change")
                    }
                }
                let ruler = try s.element("ruler")
                s.expect(try s.held(MenuItemContract.isOn, on: ruler), false, "made unchecked")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(MenuItemContract.isOn, on: ruler) == true }
                s.expect(try s.held(MenuItemContract.isOn, on: ruler), true, "checked as the tree changed it")
            },
            ConformanceCase("anItemChosenTurnsItsStateOver", proves: [
                Covered(MenuItemContract.toggled, on: "MenuItem"), Covered(MenuItemContract.isOn, on: "MenuItem"),
            ]) { s in
                let on = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    Text("Row").contextMenu {
                        MenuItem("Ruler").isOn(on.projectedValue).onToggled { heard.values.append($0) }.id("ruler")
                    }.id("row")
                }

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { on.wrappedValue }
                s.expect(on.wrappedValue, true, "chosen unchecked, the state turns on")
                try s.settle { try s.held(MenuItemContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(MenuItemContract.isOn, on: s.element("ruler")), true, "and the item stands checked")

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { !on.wrappedValue }
                s.expect(on.wrappedValue, false, "chosen checked, the state turns off")
                s.expect(heard.values, [true, false], "each turn heard with the way it turned")
            },
        ]
    }
}
