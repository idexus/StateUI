// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `MenuItemContract` on a host: an item chosen from a view's menu runs its own handler, one in a submenu too.
@_spi(Host) public enum MenuItemTests: ConformanceFamily {
    public static let name = "MenuItem"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anItemChosenRunsItsOwnHandler", covers: [
                Covered(MenuItemContract.self), Covered(MenuItemElementContract.clicked, on: "MenuItem"),
            ]) { s in
                let heard = Received<String>()
                s.start { MenuPage(heard: heard) }

                try s.perform(.activate, on: s.element("share Mail"))
                s.settle { heard.values == ["share Mail"] }
                try s.perform(.activate, on: s.element("copy"))
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["share Mail", "copy"], "each item its own handler, a submenu's too")
            },
        ]
    }
}
