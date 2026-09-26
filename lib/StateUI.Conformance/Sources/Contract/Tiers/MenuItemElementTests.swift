// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuItemElementContract` on a host: an item - a menu's, a toolbar's - chosen runs its handler, one out of reach
/// runs nothing, and it stands with the words, icon and warning the tree gives it; each case made for every element
/// wearing the tier.
@_spi(Host) public enum MenuItemElementTests: ConformanceFamily {
    public static let name = "MenuItemElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(MenuItemElementContract.self).flatMap { element in
            [
                chosen(element),
                Aspects.holds(MenuItemElementContract.text, on: element, "Copy", then: "Duplicate"),
                Aspects.holds(MenuItemElementContract.icon, on: element, "test_dot.png", then: "test_wide.png"),
                Aspects.holds(MenuItemElementContract.isDestructive, on: element, false, then: true),
                Aspects.holds(MenuItemElementContract.isEnabled, on: element, true, then: false),
            ]
        }
    }

    /// An item chosen runs its handler; out of reach, it runs nothing.
    static func chosen(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).anItemChosenRunsItsHandlerUnlessOutOfReach", covers: [
            Covered(MenuItemElementContract.clicked, on: element), Covered(MenuItemElementContract.isEnabled, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                Chosen.page(element) { enabled in
                    (enabled ? "on" : "off", { heard.values.append(enabled ? "on" : "off") })
                }
            }

            try s.perform(.activate, on: s.element("on"))
            s.settle { heard.values == ["on"] }
            try? s.perform(.activate, on: s.element("off"))
            s.turn()
            s.expect(heard.values, ["on"], "the item out of reach ran nothing")
        }
    }
}

/// Two items of one kind - one in reach, one out of it - each on the page where an application puts it.
enum Chosen {
    /// A page with an item of `element`'s kind in reach and one out of it, each named and heard as `item` says.
    static func page(
        _ element: String, _ item: @escaping @Sendable (Bool) -> (String, @Sendable () -> Void)
    ) -> any Page {
        let (on, off) = (item(true), item(false))
        if element == "ToolbarItem" {
            return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                SessionPage { page, _ in
                    page.toolbarItems = [
                        ToolbarItem(on.0).onClicked { on.1() }.id(on.0),
                        ToolbarItem(off.0).isEnabled(false).onClicked { off.1() }.id(off.0),
                    ]
                }
            } destination: { _ in Label("Pushed") }
        }
        return VStack {
            Label("Row").contextMenu {
                MenuItem(on.0).onClicked { on.1() }.id(on.0)
                MenuItem(off.0).isEnabled(false).onClicked { off.1() }.id(off.0)
            }.id("row")
        }
    }
}
