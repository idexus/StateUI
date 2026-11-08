// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `EnabledElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum EnabledElementTests: ConformanceFamily {
    public static let name = "EnabledElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("ToolbarGroup.aDisabledGroupsItemsAreOutOfReach", proves: [
                Covered(EnabledElementContract.isEnabled, on: ToolbarGroupContract.self),
            ]) { s in
                s.start {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        Text("Page").toolbar {
                            ToolbarGroup {
                                ToolbarButton("Bold").id("bold")
                                ToolbarButton("Italic").id("italic")
                            }
                            .isEnabled(false)
                        }
                    } destination: { _ in Text("Pushed") }
                }
                let bar = { try s.bar(of: try shownPage(s)) }

                try s.settle { try bar() == "|[!bold !italic]|" }
                s.expect(try bar(), "|[!bold !italic]|")
            },
        ] + (VisualElementTests.written + MenuItemElementCases.written + MenuTests.written + ToolbarGroupTests.written)
            .proving(EnabledElementContract.self)
    }
}
