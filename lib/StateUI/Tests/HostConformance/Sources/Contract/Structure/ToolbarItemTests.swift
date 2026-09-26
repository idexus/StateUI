// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ToolbarItemContract` on a host: an item on the visible page's bar runs its handler when chosen, stands where its
/// placement puts it - on the bar or in its overflow - and in its priority's order.
@_spi(Host) public enum ToolbarItemTests: ConformanceFamily {
    public static let name = "ToolbarItem"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anItemChosenRunsItsHandler", covers: [
                Covered(ToolbarItemContract.self), Covered(MenuItemElementContract.clicked, on: "ToolbarItem"),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    Self.page {
                        [
                            ToolbarItem("Save").onClicked { heard.values.append("save") }.id("save"),
                            ToolbarItem("Delete").placement(.overflow).onClicked { heard.values.append("delete") }.id("delete"),
                        ]
                    }
                }

                try s.perform(.activate, on: s.element("save"))
                s.settle { heard.values == ["save"] }
                try s.perform(.activate, on: s.element("delete"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["save", "delete"], "on the bar and in its overflow alike")
            },
            ConformanceCase("anItemStandsWhereItsPlacementPutsIt", covers: [
                Covered(ToolbarItemContract.placement), Covered(ButtonContract.clicked),
            ]) { s in
                let away = State(wrappedValue: false)
                s.start {
                    Self.page(beside: [Button("Away").onClicked { away.wrappedValue = true }.id("change")],
                              key: "\(away.wrappedValue)") {
                        [ToolbarItem("Save").placement(away.wrappedValue ? .overflow : .bar).id("save")]
                    }
                }
                let item = try s.element("save")
                try s.settle { try s.held(ToolbarItemContract.placement, on: item) == .bar }
                s.expect(try s.held(ToolbarItemContract.placement, on: item), .bar)

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ToolbarItemContract.placement, on: s.element("save")) == .overflow }
                s.expect(try s.held(ToolbarItemContract.placement, on: s.element("save")), .overflow)
            },
            ConformanceCase("itemsStandInTheirPrioritysOrder", covers: [Covered(ToolbarItemContract.priority)]) { s in
                s.start {
                    Self.page {
                        [
                            ToolbarItem("Later").priority(2).id("later"),
                            ToolbarItem("First").priority(0).id("first"),
                            ToolbarItem("Second").priority(1).id("second"),
                        ]
                    }
                }

                s.expect(try ["first", "second", "later"].map { try s.held(ToolbarItemContract.priority, on: s.element($0)) },
                         [0, 1, 2], "each where its priority stands it")
            },
        ]
    }

    /// A page inside a navigation stack putting `items` on its bar - again whenever `key` changes - with words and
    /// what stands `beside` them.
    static func page(
        beside: [any View] = [], key: String = "", _ items: @escaping @Sendable () -> [ToolbarItem]
    ) -> any Page {
        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            SessionPage(beside: beside.map { $0 }, key: key) { page, _ in page.toolbarItems = items() }
        } destination: { _ in Label("Pushed") }
    }
}
