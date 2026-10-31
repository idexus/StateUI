// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarLabelContract` on a host: words on the visible page's bar show what the tree says, with their picture, and
/// behind the overflow stand as an entry nobody chooses.
@_spi(Host) public enum ToolbarLabelTests: ConformanceFamily {
    public static let name = "ToolbarLabel"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aLabelShowsTheWordsTheTreeSays", proves: [
                Covered(ToolbarLabelContract.self), Covered(ToolbarLabelContract.text),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let count = State(wrappedValue: 3)
                s.start {
                    Self.page(beside: [Button("Add").onClicked { count.wrappedValue += 1 }.id("add")],
                              key: "\(count.wrappedValue)") {
                        [ToolbarLabel("\(count.wrappedValue) items").id("count")]
                    }
                }
                let words = { try s.held(ToolbarLabelContract.text, on: s.element("count")) }

                try s.settle { try words() == "3 items" }
                s.expect(try words(), "3 items", "made with its words")
                s.expect(try s.bar(of: try shownPage(s)), "|[count]|", "on the bar, as an action would stand")

                try s.perform(.activate, on: s.element("add"))
                try s.settle { try words() == "4 items" }
                s.expect(try words(), "4 items", "and as the tree changed them")
            },
            ConformanceCase("aLabelShowsItsPicture", proves: [Covered(ToolbarLabelContract.icon)]) { s in
                s.start { Self.page { [ToolbarLabel("Saved").icon("test_dot.png").id("saved")] } }

                try s.settle { try s.held(ToolbarLabelContract.icon, on: s.element("saved")) == "test_dot.png" }
                s.expect(try s.held(ToolbarLabelContract.icon, on: s.element("saved")), "test_dot.png")
            },
            ConformanceCase("aLabelInTheOverflowIsChosenByNobody", proves: [Covered(ToolbarLabelContract.self)]) { s in
                s.start {
                    Self.page {
                        [
                            ToolbarLabel("Saved").placement(at: .overflow).id("saved"),
                            ToolbarLabel("Synced").placement(at: .overflow).id("synced"),
                        ]
                    }
                }

                try s.settle { try s.bar(of: try shownPage(s)) == "||!saved !synced" }
                s.expect(try s.bar(of: try shownPage(s)), "||!saved !synced", "entries nobody can choose")
            },
        ]
    }

    /// A page inside a navigation stack declaring `labels` for its bar - again whenever `key` changes - with words and
    /// what stands `beside` them.
    @MainActor
    static func page(
        beside: [any View] = [], key: String = "", _ labels: @escaping @MainActor () -> [ToolbarLabel]
    ) -> some View {
        NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            DeclaringPage(beside: beside.map { $0 }, key: key, labels: labels)
        } destination: { _ in Text("Pushed") }
    }
}
