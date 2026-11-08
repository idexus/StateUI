// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The cases every item a user chooses from is held to - a menu's, a toolbar's, an action or a setting: out of reach
/// itself or with its branch it is chosen by nothing, its shortcut chooses it, and it stands with the words and icon
/// the tree gives it. The families of the tiers it wears take up the cases proving their members.
enum MenuItemElementCases {
    /// The items: every element `MenuItemElement` describes.
    static let items: [String] = [MenuItemContract.nodeType, MenuToggleContract.nodeType, ToolbarButtonContract.nodeType,
        ToolbarToggleContract.nodeType].map { $0.name }

    /// Every case written for the items, each made for every item.
    @MainActor static var written: [ConformanceCase] {
        items.flatMap { element in
            [
                chosen(element),
                outOfReachWithItsBranch(element),
                Aspects.holds(TextElementContract.text, on: element, "Copy", then: "Duplicate"),
                Aspects.holds(IconElementContract.icon, on: element, "test_dot.png", then: "test_wide.png"),
                Aspects.holds(EnabledElementContract.isEnabled, on: element, true, then: false),
                Aspects.holds(
                    ShortcutElementContract.keyboardShortcut, on: element, KeyboardShortcut("s"),
                    then: KeyboardShortcut("s", modifiers: [.primary, .shift])),
                chosenByItsShortcut(element),
                givesWayToTyping(element),
            ]
        }
    }

    /// What tells an item of `element`'s kind was chosen: an action's click, a setting's turn.
    static func choosing(_ element: String) -> Covered {
        switch element {
        case "MenuToggle", "ToolbarToggle": Covered(ToggleElementContract.toggled, on: element)
        default: Covered(ClickElementContract.clicked, on: element)
        }
    }

    /// An item chosen runs its handler; out of reach, it runs nothing.
    @MainActor
    static func chosen(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).anItemChosenRunsItsHandlerUnlessOutOfReach", proves: [
            Covered(EnabledElementContract.isEnabled, on: element),
        ], needs: [choosing(element)]) { s in
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
            Covered(EnabledElementContract.isEnabled, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self), choosing(element)]) { s in
            let heard = Received<String>()
            let enabled = State(wrappedValue: false)
            s.start {
                Chosen.branch(element, enabled: enabled.wrappedValue,
                              beside: Button("Enable").onClicked { enabled.wrappedValue = true }.id("change")) {
                    heard.values.append("item")
                }
            }
            try s.settle { try s.held(EnabledElementContract.isEnabled, on: s.element("item")) == false }
            s.expect(try s.held(EnabledElementContract.isEnabled, on: s.element("item")), false, "disabled with it")
            try? s.perform(.activate, on: s.element("item"))
            s.turn()
            s.expect(heard.values, [], "out of reach, it ran nothing")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(EnabledElementContract.isEnabled, on: s.element("item")) == true }
            s.expect(try s.held(EnabledElementContract.isEnabled, on: s.element("item")), true, "enabled with it")
            try s.perform(.activate, on: s.element("item"))
            s.settle { heard.values == ["item"] }
            s.expect(heard.values, ["item"], "in reach, it runs its handler")
        }
    }
}

extension MenuItemElementCases {
    /// A shortcut chooses the item stating it while its window is in front - a bar's item, a menu bar's entry - and
    /// one out of reach nothing; a context menu's entry only shows its shortcut, and a press chooses nothing.
    @MainActor
    static func chosenByItsShortcut(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aShortcutChoosesTheItemInItsWindow", proves: [
            Covered(ShortcutElementContract.keyboardShortcut, on: element),
        ], needs: [choosing(element)]) { s in
            let heard = Received<String>()
            s.start { Shortcuts.page(element, heard: heard) }

            try s.perform(.pressKeys(KeyboardShortcut("s", modifiers: [.primary, .shift])), on: s.element("save"))
            s.settle { heard.values == ["save"] }
            s.expect(heard.values, ["save"], "the shortcut chooses its item")

            try s.perform(.pressKeys(KeyboardShortcut("o")), on: s.element("open"))
            s.turn()
            s.expect(heard.values, ["save"], "an item out of reach is chosen by nothing")
            guard element.hasPrefix("Menu") else { return }

            try s.perform(.pressKeys(KeyboardShortcut("c")), on: s.element("copy"))
            s.turn()
            s.expect(heard.values, ["save"], "a context menu's entry only shows its shortcut")
        }
    }

    /// A key held alone is the character a field being typed into writes, not the item's shortcut.
    @MainActor
    static func givesWayToTyping(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aBareShortcutGivesWayToAFieldBeingTypedInto", proves: [
            Covered(ShortcutElementContract.keyboardShortcut, on: element),
        ], needs: [
            choosing(element),
            Covered(FocusElementContract.focus, on: "TextField"),
        ]) { s in
            let heard = Received<String>()
            s.start { Shortcuts.page(element, heard: heard) }
            let field = try s.element("field")

            try s.perform(.focus, on: field)
            try s.settle { try s.focused(field) }
            try s.perform(.pressKeys(KeyboardShortcut("1", modifiers: [])), on: s.element("one"))
            s.turn()
            s.expect(heard.values, [], "the key is the field's, the item stays as it was")
        }
    }
}

/// A page with items of one kind stating shortcuts, each where an application puts it: "Save" on ⌘⇧S or Ctrl+Shift+S,
/// "Open" out of reach on ⌘O, "One" on 1 alone beside a field - for a menu's entry on the window's menu bar - and a
/// context menu's "Copy" on ⌘C beside them.
@MainActor
enum Shortcuts {
    static func page(_ element: String, heard: Received<String>) -> AnyView {
        let content = VStack {
            Text("Page").id("page")
            TextField("").id("field")
            if element == "MenuItem" {
                Text("Row").contextMenu {
                    MenuItem("Copy").keyboardShortcut("c").onClicked { heard.values.append("copy") }.id("copy")
                }
                .id("row")
            }
            if element == "MenuToggle" {
                Text("Row").contextMenu {
                    MenuToggle("Copy", isOn: false).keyboardShortcut("c")
                        .onToggled { _ in heard.values.append("copy") }.id("copy")
                }
                .id("row")
            }
        }
        if element == "ToolbarToggle" {
            let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                content.toolbar {
                    ToolbarToggle("Save", isOn: false).keyboardShortcut("s", modifiers: [.primary, .shift])
                        .onToggled { _ in heard.values.append("save") }.id("save")
                    ToolbarToggle("Open", isOn: false).keyboardShortcut("o").isEnabled(false)
                        .onToggled { _ in heard.values.append("open") }.id("open")
                    ToolbarToggle("One", isOn: false).keyboardShortcut("1", modifiers: [])
                        .onToggled { _ in heard.values.append("one") }.id("one")
                }
            } destination: { _ in Text("Pushed") }
            return AnyView(stack)
        }
        if element == "ToolbarButton" {
            let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                content.toolbar {
                    ToolbarButton("Save").keyboardShortcut("s", modifiers: [.primary, .shift])
                        .onClicked { heard.values.append("save") }.id("save")
                    ToolbarButton("Open").keyboardShortcut("o").isEnabled(false)
                        .onClicked { heard.values.append("open") }.id("open")
                    ToolbarButton("One").keyboardShortcut("1", modifiers: [])
                        .onClicked { heard.values.append("one") }.id("one")
                }
            } destination: { _ in Text("Pushed") }
            return AnyView(stack)
        }
        let toggles = element == "MenuToggle"
        let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            content.menuBar {
                Menu("File") {
                    if toggles {
                        MenuToggle("Save", isOn: false).keyboardShortcut("s", modifiers: [.primary, .shift])
                            .onToggled { _ in heard.values.append("save") }.id("save")
                        MenuToggle("Open", isOn: false).keyboardShortcut("o").isEnabled(false)
                            .onToggled { _ in heard.values.append("open") }.id("open")
                        MenuToggle("One", isOn: false).keyboardShortcut("1", modifiers: [])
                            .onToggled { _ in heard.values.append("one") }.id("one")
                    } else {
                        MenuItem("Save").keyboardShortcut("s", modifiers: [.primary, .shift])
                            .onClicked { heard.values.append("save") }.id("save")
                        MenuItem("Open").keyboardShortcut("o").isEnabled(false)
                            .onClicked { heard.values.append("open") }.id("open")
                        MenuItem("One").keyboardShortcut("1", modifiers: [])
                            .onClicked { heard.values.append("one") }.id("one")
                    }
                }
            }
        } destination: { _ in Text("Pushed") }
        return AnyView(stack)
    }
}

/// Two items of one kind - one in reach, one out of it - each on the page where an application puts it.
@MainActor
enum Chosen {
    /// A page with an item of `element`'s kind in reach and one out of it, each named and heard as `item` says.
    static func page(
        _ element: String, _ item: @escaping @MainActor (Bool) -> (String, @MainActor () -> Void)
    ) -> AnyView {
        // Chosen by name, so held as `any View` and handed on as its node.
        AnyView(chosen(element, item))
    }

    /// The page `page(_:_:)` shows, chosen by name.
    private static func chosen(
        _ element: String, _ item: @escaping @MainActor (Bool) -> (String, @MainActor () -> Void)
    ) -> any View {
        let (on, off) = (item(true), item(false))
        if element == "ToolbarToggle" {
            return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                DeclaringPage(toggles: {
                    [
                        ToolbarToggle(on.0, isOn: false).onToggled { _ in on.1() }.id(on.0),
                        ToolbarToggle(off.0, isOn: false).isEnabled(false).onToggled { _ in off.1() }.id(off.0),
                    ]
                })
            } destination: { _ in Text("Pushed") }
        }
        if element == "ToolbarButton" {
            return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                DeclaringPage {
                    [
                        ToolbarButton(on.0).onClicked { on.1() }.id(on.0),
                        ToolbarButton(off.0).isEnabled(false).onClicked { off.1() }.id(off.0),
                    ]
                }
            } destination: { _ in Text("Pushed") }
        }
        if element == "MenuToggle" {
            return VStack {
                Text("Row").contextMenu {
                    MenuToggle(on.0, isOn: false).onToggled { _ in on.1() }.id(on.0)
                    MenuToggle(off.0, isOn: false).isEnabled(false).onToggled { _ in off.1() }.id(off.0)
                }.id("row")
            }
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
    ) -> AnyView {
        let branch: any View = switch element {
        case "ToolbarButton":
            VStack { Text("Branch") }.toolbar { ToolbarButton("Item").onClicked { heard() }.id("item") }
        case "MenuToggle":
            VStack {
                Text("Row").contextMenu { MenuToggle("Item", isOn: false).onToggled { _ in heard() }.id("item") }.id("row")
            }
        case "ToolbarToggle":
            VStack { Text("Branch") }.toolbar { ToolbarToggle("Item", isOn: false).onToggled { _ in heard() }.id("item") }
        default:
            VStack { Text("Row").contextMenu { MenuItem("Item").onClicked { heard() }.id("item") }.id("row") }
        }
        let page = VStack { Beside([Text("Page"), AnyView(branch).isEnabled(enabled), beside]) }
        guard element.hasPrefix("Toolbar") else { return AnyView(page) }
        // An item on a bar stands on a page in a navigation stack.
        let stack = NavigationStack(State(wrappedValue: [Int]()).projectedValue) { page } destination: { _ in Text("Pushed") }
        return AnyView(stack)
    }
}
