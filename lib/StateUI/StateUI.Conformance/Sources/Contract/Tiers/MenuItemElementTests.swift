// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MenuItemElementContract` on a host: an item - a menu's, a toolbar's - chosen runs its handler, one out of reach
/// itself or with its branch runs nothing, and it stands with the words, icon and warning the tree gives it; each
/// case made for every element wearing the tier.
@_spi(Host) public enum MenuItemElementTests: ConformanceFamily {
    public static let name = "MenuItemElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(MenuItemElementContract.self).flatMap { element in
            [
                chosen(element),
                outOfReachWithItsBranch(element),
                Aspects.holds(MenuItemElementContract.text, on: element, "Copy", then: "Duplicate"),
                Aspects.holds(MenuItemElementContract.icon, on: element, "test_dot.png", then: "test_wide.png"),
                Aspects.holds(MenuItemElementContract.isDestructive, on: element, false, then: true),
                Aspects.holds(MenuItemElementContract.isEnabled, on: element, true, then: false),
            ]
        }
    }

    /// An item chosen runs its handler; out of reach, it runs nothing.
    @MainActor
    static func chosen(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).anItemChosenRunsItsHandlerUnlessOutOfReach", proves: [
            Covered(MenuItemElementContract.clicked, on: element), Covered(MenuItemElementContract.isEnabled, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                Chosen.page(element) { enabled in
                    (enabled ? "on" : "off", { @MainActor in heard.values.append(enabled ? "on" : "off") })
                }
            }

            try s.perform(.activate, on: s.element("on"))
            s.settle { heard.values == ["on"] }
            try? s.perform(.activate, on: s.element("off"))
            s.turn()
            s.expect(heard.values, ["on"], "the item out of reach ran nothing")
        }
    }

    /// An item declared in a branch the tree disables is out of reach - it stands disabled and runs nothing - and is
    /// in reach again as the branch is enabled.
    @MainActor
    static func outOfReachWithItsBranch(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).anItemInADisabledBranchIsOutOfReach", proves: [
            Covered(MenuItemElementContract.isEnabled, on: element),
        ], needs: [Covered(ButtonContract.clicked), Covered(MenuItemElementContract.clicked, on: element)]) { s in
            let heard = Received<String>()
            let enabled = State(wrappedValue: false)
            s.start {
                Chosen.branch(element, enabled: enabled.wrappedValue,
                              beside: Button("Enable").onClicked { enabled.wrappedValue = true }.id("change")) {
                    heard.values.append("item")
                }
            }
            try s.settle { try s.held(MenuItemElementContract.isEnabled, on: s.element("item")) == false }
            s.expect(try s.held(MenuItemElementContract.isEnabled, on: s.element("item")), false, "disabled with it")
            try? s.perform(.activate, on: s.element("item"))
            s.turn()
            s.expect(heard.values, [], "out of reach, it ran nothing")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(MenuItemElementContract.isEnabled, on: s.element("item")) == true }
            s.expect(try s.held(MenuItemElementContract.isEnabled, on: s.element("item")), true, "enabled with it")
            try s.perform(.activate, on: s.element("item"))
            s.settle { heard.values == ["item"] }
            s.expect(heard.values, ["item"], "in reach, it runs its handler")
        }
    }
}

/// Two items of one kind - one in reach, one out of it - each on the page where an application puts it.
@MainActor
enum Chosen {
    /// A page with an item of `element`'s kind in reach and one out of it, each named and heard as `item` says.
    static func page(
        _ element: String, _ item: @escaping @MainActor (Bool) -> (String, @MainActor () -> Void)
    ) -> ModifiedContent {
        // Chosen by name, so held as `any View` and handed on as its node.
        ModifiedContent(node: chosen(element, item).node)
    }

    /// The page `page(_:_:)` shows, chosen by name.
    private static func chosen(
        _ element: String, _ item: @escaping @MainActor (Bool) -> (String, @MainActor () -> Void)
    ) -> any View {
        let (on, off) = (item(true), item(false))
        if element == "ToolbarItem" {
            return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                DeclaringPage {
                    [
                        ToolbarItem(on.0).onClicked { on.1() }.id(on.0),
                        ToolbarItem(off.0).isEnabled(false).onClicked { off.1() }.id(off.0),
                    ]
                }
            } destination: { _ in Text("Pushed") }
        }
        return VStack {
            Text("Row").contextMenu {
                MenuItem(on.0).onClicked { on.1() }.id(on.0)
                MenuItem(off.0).isEnabled(false).onClicked { off.1() }.id(off.0)
            }.id("row")
        }
    }

    /// A page with an item of `element`'s kind, found by the id "item" and heard by `heard`, declared in a branch
    /// `enabled` says, `beside` it out of the branch.
    static func branch(
        _ element: String, enabled: Bool, beside: some View, _ heard: @escaping @MainActor () -> Void
    ) -> ModifiedContent {
        let branch: any View = element == "ToolbarItem"
            ? VStack { Text("Branch") }.toolbar { ToolbarItem("Item").onClicked { heard() }.id("item") }
            : VStack { Text("Row").contextMenu { MenuItem("Item").onClicked { heard() }.id("item") }.id("row") }
        let page = VStack { [Text("Page"), ModifiedContent(node: branch.node).isEnabled(enabled), beside] as [any View] }
        guard element == "ToolbarItem" else { return ModifiedContent(node: page.node) }
        // An item on a bar stands on a page in a navigation stack.
        let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) { page } destination: { _ in Text("Pushed") }
        return ModifiedContent(node: stack.node)
    }
}
