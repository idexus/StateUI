// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarButtonContract` on a host: an item on the visible page's bar runs its handler when chosen - on the bar or in
/// its overflow alike - its words beside its picture where it says so.
@_spi(Host) public enum ToolbarButtonTests: ConformanceFamily {
    public static let name = "ToolbarButton"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anItemChosenRunsItsHandler", proves: [
                Covered(ToolbarButtonContract.self),
            ], needs: [Covered(ActionElementContract.clicked, on: "ToolbarButton")]) { s in
                let heard = Received<String>()
                s.start {
                    Self.page {
                        [
                            ToolbarButton("Save").onClicked { heard.values.append("save") }.id("save"),
                            ToolbarButton("Delete").placement(at: .overflow).onClicked { heard.values.append("delete") }
                                .id("delete"),
                        ]
                    }
                }

                try s.perform(.activate, on: s.element("save"))
                s.settle { heard.values == ["save"] }
                try s.perform(.activate, on: s.element("delete"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["save", "delete"], "on the bar and in its overflow alike")
            },
        ]
    }

    /// A page inside a navigation stack declaring `items` for its bar - again whenever `key` changes - with words and
    /// what stands `beside` them.
    @MainActor
    static func page(
        beside: [any View] = [], key: String = "", _ items: @escaping @MainActor () -> [ToolbarButton]
    ) -> some View {
        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            DeclaringPage(beside: beside.map { $0 }, key: key, items)
        } destination: { _ in Text("Pushed") }
    }
}
