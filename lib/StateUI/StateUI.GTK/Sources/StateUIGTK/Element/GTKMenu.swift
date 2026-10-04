// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A menu as GTK's menus hold one: the host layer's walk of its entries (`MenuEntry`) as a `GMenu` - the entries
/// between two separators a section, a submenu a link - each item an action of the group the menu hands the widget
/// it stands on, enabled where the item can be chosen. GNOME's menus show words alone: no picture, no warning.
/// Design: docs/design/platforms/gtk/pages.md#menus
@MainActor
final class GTKMenu {
    /// The prefix the menu's actions stand under on the widget they are handed to.
    static let actionGroup = "stateui-menu"

    /// The model, held until the menu goes.
    let model: OpaquePointer

    /// The actions its items run, by name.
    let actions: UnsafeMutablePointer<GSimpleActionGroup>

    /// Each item's element, by its action's name.
    private(set) var items: [String: () -> MountedElement?] = [:]

    /// The numbers its actions' signals carry.
    private var numbers: [Int64] = []

    /// What the menu draws: its entries' kinds, captions and whether each can be chosen, in order.
    private(set) var drawn: [String] = []

    /// The elements its items run, in order.
    private var runs: [ObjectIdentifier?] = []

    /// How many submenus it holds, each with the action it opens by.
    private var submenus = 0

    /// Whether the menu holds no entries.
    var isEmpty: Bool { drawn.isEmpty }

    /// The menu of `entries`.
    init(_ entries: [MenuEntry]) {
        model = g_menu_new()
        actions = g_simple_action_group_new()!
        add(entries, to: model)
    }

    isolated deinit {
        for number in numbers { Self.chosen[number] = nil }
        g_object_unref(UnsafeMutableRawPointer(model))
        g_object_unref(UnsafeMutableRawPointer(actions))
    }

    /// Whether the menu stands as `other` does: the same entries, captions and items that can be chosen, each run by
    /// the same element.
    func stands(like other: GTKMenu?) -> Bool {
        drawn == other?.drawn && runs == other?.runs
    }

    /// Adds `entries` to `menu`, a section between each two separators.
    private func add(_ entries: [MenuEntry], to menu: OpaquePointer) {
        let sections = entries.split(omittingEmptySubsequences: true) { $0.kind == .separator }
        for (index, section) in sections.enumerated() {
            if index > 0 { drawn.append("-") }
            let part = sections.count > 1 ? g_menu_new()! : menu
            for entry in section { add(entry, to: part) }
            guard sections.count > 1 else { continue }
            g_menu_append_section(menu, nil, g_menu_model(part))
            g_object_unref(UnsafeMutableRawPointer(part))
        }
    }

    /// Adds an item, or a submenu holding its own entries.
    private func add(_ entry: MenuEntry, to menu: OpaquePointer) {
        drawn.append((entry.isEnabled ? "" : "!") + entry.title + (entry.kind == .submenu ? "[" : ""))
        if entry.kind == .submenu {
            let submenu = g_menu_new()!
            add(entry.entries, to: submenu)
            drawn.append("]")
            // A submenu out of reach is one whose action - the one GTK tracks it open by - cannot run.
            let name = "s\(submenus)"
            submenus += 1
            let opens = g_simple_action_new_stateful(name, nil, g_variant_new_boolean(0))!
            g_simple_action_set_enabled(opens, entry.isEnabled ? 1 : 0)
            g_action_map_add_action(OpaquePointer(actions), opens)
            g_object_unref(UnsafeMutableRawPointer(opens))
            let item = g_menu_item_new_submenu(entry.title, g_menu_model(submenu))!
            g_menu_item_set_attribute_value(item, "submenu-action", g_variant_new_string(Self.actionGroup + "." + name))
            g_menu_append_item(menu, item)
            g_object_unref(UnsafeMutableRawPointer(item))
            g_object_unref(UnsafeMutableRawPointer(submenu))
            return
        }
        let name = "e\(items.count)"
        let action = g_simple_action_new(name, nil)!
        g_simple_action_set_enabled(action, entry.isEnabled ? 1 : 0)
        let element = entry.element
        items[name] = { [weak element] in element }
        runs.append(element.map(ObjectIdentifier.init))
        let number = Self.nextNumber
        Self.nextNumber += 1
        numbers.append(number)
        Self.chosen[number] = { [weak element] in element }
        connectSignal(UnsafeMutableRawPointer(action), "activate", number: number) {
            (_: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, data: gpointer?) in
            MainActor.assumeIsolated { GTKMenu.chosen[viewNumber(data)]?()?.gtk.send(.clicked, []) }
        }
        g_action_map_add_action(OpaquePointer(actions), action)
        g_object_unref(UnsafeMutableRawPointer(action))
        let item = g_menu_item_new(entry.title, Self.actionGroup + "." + name)!
        g_menu_append_item(menu, item)
        g_object_unref(UnsafeMutableRawPointer(item))
    }

    /// Every item's element, by the number its action's signal carries, one across the process.
    private static var chosen: [Int64: () -> MountedElement?] = [:]
    private static var nextNumber: Int64 = 1
}

/// The model of a `GMenu`, as GTK's menus take it.
func g_menu_model(_ menu: OpaquePointer) -> UnsafeMutablePointer<GMenuModel> {
    UnsafeMutablePointer<GMenuModel>(menu)
}
