// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `TitleBarContract` on a host: the title bar a window is given stands over it, saying its title and subtitle, with
/// its icon and in its colour, and says what the tree changes them to.
@_spi(Host) public enum TitleBarTests: ConformanceFamily {
    public static let name = "TitleBar"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aTitleBarStandsOverItsWindow", covers: [
                Covered(TitleBarContract.self), Covered(TitleBarContract.title),
            ]) { s in
                s.start { Specimens.page("TitleBar", [Write(TitleBarContract.title, "Notes")]) }
                let bar = try s.specimen("TitleBar")

                s.expect(try s.held(VisualElementContract.isVisible, on: bar), true)
                s.expect(try s.held(TitleBarContract.title, on: bar), "Notes")
            },
            Aspects.holds(TitleBarContract.title, on: "TitleBar", "Notes", then: "Drafts"),
            Aspects.holds(TitleBarContract.subtitle, on: "TitleBar", "Three notes", then: "Four notes"),
            Aspects.holds(TitleBarContract.icon, on: "TitleBar", "test_dot.png", then: "test_wide.png"),
            Aspects.holds(TitleBarContract.barForegroundColor, on: "TitleBar", .white, then: .black),
        ]
    }
}
