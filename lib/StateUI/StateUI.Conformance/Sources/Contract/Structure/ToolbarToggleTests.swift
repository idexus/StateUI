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
                Covered(ToolbarToggleContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let on = State(wrappedValue: false)
                s.start {
                    Self.page(beside: [Button("Change").onClicked { on.wrappedValue.toggle() }.id("change")],
                              key: "\(on.wrappedValue)") {
                        [ToolbarToggle("Ruler", isOn: on.wrappedValue).id("ruler")]
                    }
                }
                try s.settle { try s.held(ToggleElementContract.isOn, on: s.element("ruler")) == false }
                s.expect(try s.held(ToggleElementContract.isOn, on: s.element("ruler")), false, "made off")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ToggleElementContract.isOn, on: s.element("ruler")) == true }
                s.expect(try s.held(ToggleElementContract.isOn, on: s.element("ruler")), true, "on as the tree changed it")
            },

            ConformanceCase("anItemShowsItsOnPictureWhileOn", proves: [
                Covered(ToolbarToggleContract.onIcon),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let on = State(wrappedValue: false)
                s.start {
                    Self.page(beside: [Button("Change").onClicked { on.wrappedValue.toggle() }.id("change")],
                              key: "\(on.wrappedValue)") {
                        [ToolbarToggle("Ruler", isOn: on.wrappedValue).icon("test_dot.png", on: "test_wide.png").id("ruler")]
                    }
                }
                try s.settle { try s.held(IconElementContract.icon, on: s.element("ruler")) == "test_dot.png" }
                s.expect(try s.held(IconElementContract.icon, on: s.element("ruler")), "test_dot.png", "off, its own")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(IconElementContract.icon, on: s.element("ruler")) == "test_wide.png" }
                s.expect(try s.held(IconElementContract.icon, on: s.element("ruler")), "test_wide.png", "on, its on picture")
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
