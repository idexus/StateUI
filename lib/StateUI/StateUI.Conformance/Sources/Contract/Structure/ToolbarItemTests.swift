// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarItemContract` on a host: an item on the visible page's bar runs its handler when chosen, stands where its
/// placement puts it - on the bar or in its overflow - its words beside its picture where it says so.
@_spi(Host) public enum ToolbarItemTests: ConformanceFamily {
    public static let name = "ToolbarItem"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anItemChosenRunsItsHandler", proves: [
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
            ConformanceCase("anItemStandsWhereItsPlacementPutsIt", proves: [
                Covered(ToolbarItemContract.placement),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
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
            ConformanceCase("anItemsWordsStandBesideItsPictureWhereItSaysSo", proves: [
                Covered(ToolbarItemContract.showsText),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let words = State(wrappedValue: true)
                s.start {
                    Self.page(beside: [Button("Picture alone").onClicked { words.wrappedValue = false }.id("change")],
                              key: "\(words.wrappedValue)") {
                        [ToolbarItem("Save").icon("test_dot.png").showsText(words.wrappedValue).id("save")]
                    }
                }
                try s.settle { try s.held(ToolbarItemContract.showsText, on: s.element("save")) == true }
                s.expect(try s.held(ToolbarItemContract.showsText, on: s.element("save")), true)

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ToolbarItemContract.showsText, on: s.element("save")) == false }
                s.expect(try s.held(ToolbarItemContract.showsText, on: s.element("save")), false)
            },
        ]
    }

    /// A page inside a navigation stack declaring `items` for its bar - again whenever `key` changes - with words and
    /// what stands `beside` them.
    @MainActor
    static func page(
        beside: [any View] = [], key: String = "", _ items: @escaping @MainActor () -> [ToolbarItem]
    ) -> some View {
        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            DeclaringPage(beside: beside.map { $0 }, key: key, items)
        } destination: { _ in Text("Pushed") }
    }
}
