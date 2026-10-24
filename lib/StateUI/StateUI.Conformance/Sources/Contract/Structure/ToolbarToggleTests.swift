// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarToggleContract` on a host: a setting on the visible page's bar stands on as the tree says, choosing it turns
/// its state over - on the bar or in its overflow alike - it shows its `on:` picture while on, and its words beside
/// its picture where it says so.
@_spi(Host) public enum ToolbarToggleTests: ConformanceFamily {
    public static let name = "ToolbarToggle"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anItemStandsOnAsTheTreeSays", proves: [
                Covered(ToolbarToggleContract.self), Covered(ToolbarToggleContract.isOn),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let on = State(wrappedValue: false)
                s.start {
                    Self.page(beside: [Button("Change").onClicked { on.wrappedValue.toggle() }.id("change")],
                              key: "\(on.wrappedValue)") {
                        [ToolbarToggle("Ruler", isOn: on.wrappedValue).id("ruler")]
                    }
                }
                try s.settle { try s.held(ToolbarToggleContract.isOn, on: s.element("ruler")) == false }
                s.expect(try s.held(ToolbarToggleContract.isOn, on: s.element("ruler")), false, "made off")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ToolbarToggleContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(ToolbarToggleContract.isOn, on: s.element("ruler")), true, "on as the tree changed it")
            },
            ConformanceCase("anItemChosenTurnsItsStateOver", proves: [
                Covered(ToolbarToggleContract.toggled), Covered(ToolbarToggleContract.isOn),
            ]) { s in
                let ruler = State(wrappedValue: false)
                let grid = State(wrappedValue: false)
                let heard = Received<Bool>()
                s.start {
                    Self.page {
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
                try s.settle { try s.held(ToolbarToggleContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(ToolbarToggleContract.isOn, on: s.element("ruler")), true, "and the item stands on")

                try s.perform(.activate, on: s.element("ruler"))
                s.settle { !ruler.wrappedValue }
                s.expect(ruler.wrappedValue, false, "chosen on, the state turns off")
                s.expect(heard.values, [true, false], "each turn heard with the way it turned")

                try s.perform(.activate, on: s.element("grid"))
                s.settle { grid.wrappedValue }
                s.expect(grid.wrappedValue, true, "one in the overflow turns alike")
            },
            ConformanceCase("anItemShowsItsOnPictureWhileOn", proves: [
                Covered(ToolbarToggleContract.onIcon),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let on = State(wrappedValue: false)
                s.start {
                    Self.page(beside: [Button("Change").onClicked { on.wrappedValue.toggle() }.id("change")],
                              key: "\(on.wrappedValue)") {
                        [ToolbarToggle("Ruler", isOn: on.wrappedValue).icon("test_dot.png", on: "test_wide.png").id("ruler")]
                    }
                }
                try s.settle { try s.held(MenuItemElementContract.icon, on: s.element("ruler")) == "test_dot.png" }
                s.expect(try s.held(MenuItemElementContract.icon, on: s.element("ruler")), "test_dot.png", "off, its own")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(MenuItemElementContract.icon, on: s.element("ruler")) == "test_wide.png" }
                s.expect(try s.held(MenuItemElementContract.icon, on: s.element("ruler")), "test_wide.png", "on, its on picture")
            },
            ConformanceCase("anItemsWordsStandBesideItsPictureWhereItSaysSo", proves: [
                Covered(ToolbarToggleContract.showsText),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let words = State(wrappedValue: true)
                s.start {
                    Self.page(beside: [Button("Picture alone").onClicked { words.wrappedValue = false }.id("change")],
                              key: "\(words.wrappedValue)") {
                        [ToolbarToggle("Ruler", isOn: false).icon("test_dot.png").showsText(words.wrappedValue).id("ruler")]
                    }
                }
                try s.settle { try s.held(ToolbarToggleContract.showsText, on: s.element("ruler")) == true }
                s.expect(try s.held(ToolbarToggleContract.showsText, on: s.element("ruler")), true)

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ToolbarToggleContract.showsText, on: s.element("ruler")) == false }
                s.expect(try s.held(ToolbarToggleContract.showsText, on: s.element("ruler")), false)
            },
        ]
    }

    /// A page inside a navigation stack declaring `toggles` for its bar - again whenever `key` changes - with words
    /// and what stands `beside` them.
    @MainActor
    static func page(
        beside: [any View] = [], key: String = "", _ toggles: @escaping @MainActor () -> [ToolbarToggle]
    ) -> some View {
        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            DeclaringPage(beside: beside.map { $0 }, key: key, toggles: toggles)
        } destination: { _ in Text("Pushed") }
    }
}
