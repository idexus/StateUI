// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `IconElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum IconElementTests: ConformanceFamily {
    public static let name = "IconElement"

    public static var cases: [ConformanceCase] {
        [
            Aspects.holds(IconElementContract.icon, on: "Button", "test_dot.png", then: "test_wide.png",
                          with: [Write(TextElementContract.text, "Go")]),
            ConformanceCase("ToolbarLabel.aLabelShowsItsPicture", proves: [Covered(IconElementContract.icon, on: ToolbarLabelContract.self)]) { s in
                s.start { ToolbarLabelTests.page { [ToolbarLabel("Saved").icon("test_dot.png").id("saved")] } }

                try s.settle { try s.held(IconElementContract.icon, on: s.element("saved")) == "test_dot.png" }
                s.expect(try s.held(IconElementContract.icon, on: s.element("saved")), "test_dot.png")
            },
        ] + (ButtonTests.written + MenuItemElementCases.written + PageElementTests.written).proving(IconElementContract.self)
    }
}
