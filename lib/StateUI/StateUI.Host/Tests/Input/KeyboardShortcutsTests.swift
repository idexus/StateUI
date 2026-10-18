// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host reads a window's shortcuts: what a shortcut acts on, which element a pressed one reaches, and one
/// stated twice.
@MainActor
final class KeyboardShortcutsTests: XCTestCase {
    private let save = KeyboardShortcut("s")

    private func element(_ id: String, _ type: NodeType, _ shortcut: KeyboardShortcut?, enabled: Bool = true) -> HostPatch {
        var element = HostPatch(id: .manual(id), type: type)
        if let shortcut { element.properties[.keyboardShortcut] = shortcut.propValue }
        if !enabled { element.properties[.isEnabled] = .bool(false) }
        return element
    }

    private func mount(_ children: [HostPatch]) -> HostRuntime {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged(children)
        runtime.tree.apply(root, complete: true)
        return runtime
    }

    /// The first element in reading order stating the shortcut, enabled, is what a press reaches; a context menu's
    /// entry only shows its shortcut.
    func testAPressedShortcutReachesTheFirstEnabledElementStatingIt() throws {
        var menu = HostPatch(id: .manual("menu"), type: .contextMenu)
        menu.children = .arranged([element("entry", .menuItem, save)])
        var row = HostPatch(id: .manual("row"), type: .text)
        row.children = .arranged([menu])
        let runtime = mount([row, element("off", .button, save, enabled: false), element("on", .button, save)])
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(KeyboardShortcuts.target(of: save, under: root)?.id, .manual("on"))
        XCTAssertNil(KeyboardShortcuts.target(of: KeyboardShortcut(.escape, modifiers: []), under: root))
        XCTAssertFalse(KeyboardShortcuts.acts(try XCTUnwrap(root.first(id: .manual("entry")))))
    }

    /// The shortcuts a menu bar's entries state are found apart from the window's others: a toolkit whose main menu
    /// holds them keeps them off the window.
    func testAMenuBarsEntriesShortcutsAreFoundApart() throws {
        let export = KeyboardShortcut("e", modifiers: [.primary, .shift])
        var file = HostPatch(id: .manual("file"), type: .menu)
        file.children = .arranged([element("export", .menuItem, export)])
        var bar = HostPatch(id: .manual("bar"), type: .menuBar)
        bar.children = .arranged([file])
        let runtime = mount([element("save", .button, save), bar])
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(KeyboardShortcuts.onMenuBar(under: root), [export], "a button's is not the bar's")
        XCTAssertEqual(KeyboardShortcuts.stated(under: root), [save, export])
    }

    /// A shortcut two elements in sight state is said; one stated once is not.
    func testAShortcutStatedTwiceIsFound() throws {
        let runtime = mount([
            element("a", .button, save), element("b", .button, save), element("c", .button, KeyboardShortcut("o")),
        ])
        XCTAssertEqual(KeyboardShortcuts.repeated(under: try XCTUnwrap(runtime.tree.root)), [save])
        XCTAssertTrue(hasComplained("primary+s is stated twice"), "said as the patch stating it is applied")
        XCTAssertEqual(save.description, "primary+s")
        XCTAssertEqual(KeyboardShortcut(.return, modifiers: [.primary, .shift]).description, "primary+shift+return")
    }

    /// A character's key or Return, alone or with Shift, is what a field being typed into takes; held with the
    /// platform's own key or Alt, or another key writing no character, it stays a shortcut there.
    func testABareCharactersShortcutGivesWayToTyping() throws {
        XCTAssertTrue(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut("1", modifiers: [])))
        XCTAssertTrue(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut("a", modifiers: [.shift])))
        XCTAssertTrue(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut(.return, modifiers: [])))
        XCTAssertTrue(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut(.return, modifiers: [.shift])))
        XCTAssertFalse(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut(.return)))
        XCTAssertFalse(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut("s")))
        XCTAssertFalse(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut("s", modifiers: [.alt])))
        XCTAssertFalse(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut(.f5, modifiers: [])))
        XCTAssertFalse(KeyboardShortcuts.givesWayToTyping(KeyboardShortcut(.escape, modifiers: [])))

        let one = KeyboardShortcut("1", modifiers: [])
        let runtime = mount([element("one", .button, one), element("save", .button, save)])
        let root = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(KeyboardShortcuts.stated(under: root), [one, save])
        XCTAssertEqual(KeyboardShortcuts.stated(under: root, typing: true), [save], "the bare one is the field's")
        XCTAssertFalse(KeyboardShortcuts.press(one, under: root, in: runtime, typing: true))
    }

    /// A button's role gives it a key unless it states one of its own: Return its window's main action, Escape the
    /// way out, none an action destroying something.
    func testARolesKeyPressesTheButtonUnlessItStatesOne() throws {
        func button(_ id: String, _ role: ButtonRole, _ shortcut: KeyboardShortcut? = nil) -> HostPatch {
            var made = element(id, .button, shortcut)
            made.properties[.role] = role.propValue
            return made
        }
        let returnKey = KeyboardShortcut(.return, modifiers: []), escape = KeyboardShortcut(.escape, modifiers: [])
        let runtime = mount([
            button("save", .primary), button("cancel", .cancel), button("delete", .destructive),
            button("send", .primary, KeyboardShortcut("s")),
        ])
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(KeyboardShortcuts.stated(under: root), [returnKey, escape, save])
        XCTAssertEqual(KeyboardShortcuts.target(of: returnKey, under: root)?.id, .manual("save"))
        XCTAssertEqual(KeyboardShortcuts.target(of: escape, under: root)?.id, .manual("cancel"))
        XCTAssertEqual(KeyboardShortcuts.stated(under: root, typing: true), [escape, save], "Return is the field's")
    }

    /// A page beneath a stack's top is out of sight: its shortcuts reach nothing.
    /// A bar item written on an arrangement stands with it - in the arrangement's slots, not among its pages - and
    /// its shortcut reaches it, as the chrome shows it.
    func testAnArrangementsBarItemsShortcutReachesIt() throws {
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .arranged([element("body", .text, nil)])
        var group = HostPatch(id: .manual("window"), type: .toolbarItemGroup)
        group.children = .arranged([element("account", .toolbarItem, save)])
        var stack = HostPatch(id: .manual("stack"), type: .navigationStack)
        stack.children = .arranged([page, group])
        let runtime = mount([stack])
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(KeyboardShortcuts.target(of: save, under: root)?.id, .manual("account"))
    }

    func testAPageBeneathTheTopIsOutOfSight() throws {
        var below = HostPatch(id: .manual("below"), type: .page)
        below.children = .arranged([element("hidden", .button, save)])
        var top = HostPatch(id: .manual("top"), type: .page)
        top.children = .arranged([element("shown", .button, save)])
        var stack = HostPatch(id: .manual("stack"), type: .navigationStack)
        stack.children = .arranged([below, top])
        let runtime = mount([stack])
        let root = try XCTUnwrap(runtime.tree.root)

        XCTAssertEqual(KeyboardShortcuts.target(of: save, under: root)?.id, .manual("shown"))
        XCTAssertEqual(KeyboardShortcuts.repeated(under: root), [], "one in sight, one beneath it")
    }
}
