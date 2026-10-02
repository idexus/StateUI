// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuContract` on a host: a submenu stands under its caption, holds its entries, can be taken out of reach, and
/// says the caption and the reach the tree changes them to.
@_spi(Host) public enum MenuTests: ConformanceFamily {
    public static let name = "Menu"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSubmenuStandsUnderItsCaptionHoldingItsEntries", proves: [
                Covered(MenuContract.self), Covered(MenuContract.text),
            ]) { s in
                s.start { MenuPage(heard: Received()) }

                s.expect(try s.menu(of: s.element("row")).hasSuffix("Share[Mail]"), true)
            },
            ConformanceCase("aSubmenusCaptionAndReachFollowTheTree", proves: [
                Covered(MenuContract.text), Covered(MenuContract.isEnabled),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let changed = State(wrappedValue: false)
                s.start {
                    VStack {
                        Text("Row").contextMenu {
                            Menu(changed.wrappedValue ? "Send" : "Share") { MenuItem("Mail") }.isEnabled(!changed.wrappedValue)
                        }.id("row")
                        Button("Change").onClicked { changed.wrappedValue = true }.id("change")
                    }
                }
                let row = try s.element("row")
                s.expect(try s.menu(of: row), "Share[Mail]")

                // The submenu's own caption and reach: what its entries show under a submenu out of reach is each
                // platform's own - one holds them out of reach with it - and no user reaches them there.
                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.menu(of: row).hasPrefix("!Send[") }
                s.expect(try s.menu(of: row).hasPrefix("!Send["), true, "renamed, and out of reach")
            },
        ]
    }
}
