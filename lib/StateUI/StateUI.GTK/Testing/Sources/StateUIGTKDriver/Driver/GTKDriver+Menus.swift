// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What the GTK driver reads of a menu, and does in it as its user does: the entries GTK's model holds - captions,
/// sections, submenus, what can be chosen - and an item chosen through the action GTK's menu runs.
/// Design: docs/design/host/conformance.md#the-driver
extension GTKDriver {
    /// The menu `element` offers: a view's context menu, as its popover's model holds it; a window's menus, as the
    /// main menu of the page it shows holds them.
    func menu(of element: MountedElement) throws -> String {
        if element.type == .window {
            guard let page = renderer?.windows.first(where: { $0.element === element })?.presentation.arrangement?
                .visiblePage
            else { throw DriverCannot("read the menu of \(element.type.name)") }
            guard let main = try frame(of: page).mainMenu,
                  let model = gtk_menu_button_get_menu_model(main.button.opaque)
            else { return "" }
            return Self.said(model, actions: main.menu.actions)
        }
        guard let view = (element.native as? GTKElement)?.view else {
            throw DriverCannot("read the menu of \(element.type.name)")
        }
        guard let shown = view.contextMenu, let model = gtk_popover_menu_get_menu_model(shown.popover.opaque) else {
            return ""
        }
        return Self.said(model, actions: shown.menu.actions)
    }

    /// Chooses the item `element` as the user does: the action its menu runs, which GTK refuses where it cannot be
    /// chosen. Whether a menu shows it.
    func chooseMenuItem(_ element: MountedElement) throws {
        guard let (widget, _, name) = menuItem(element) else { throw DriverCannot(.activate, on: element) }
        _ = gtk_widget_activate_action_variant(widget, GTKMenu.actionGroup + "." + name, nil)
    }

    /// What the menu showing the item `element` holds of it: its caption, and whether it can be chosen.
    func menuItemHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        guard let (_, menu, name) = menuItem(element), let (holder, index) = Self.item(of: name, in: g_menu_model(menu.model))
        else { throw DriverCannot(reading: property, of: element) }
        switch property {
        case .text: return Self.attribute(holder, index, "label").map { $0.propValue }
        case .isEnabled: return (g_action_group_get_action_enabled(OpaquePointer(menu.actions), name) != 0).propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The model holding the item whose action is `name`, and its place there; nil where none is.
    private static func item(
        of name: String, in model: UnsafeMutablePointer<GMenuModel>
    ) -> (UnsafeMutablePointer<GMenuModel>, Int32)? {
        for index in 0..<g_menu_model_get_n_items(model) {
            if attribute(model, index, "action")?.hasSuffix("." + name) == true { return (model, index) }
            for link in ["section", "submenu"] {
                guard let inner = g_menu_model_get_item_link(model, index, link) else { continue }
                defer { g_object_unref(UnsafeMutableRawPointer(inner)) }
                if let found = item(of: name, in: inner) { return found }
            }
        }
        return nil
    }

    /// The widget whose menu shows the item `element` - a view its context menu, a main menu's button - the menu,
    /// and the name of its action.
    private func menuItem(_ element: MountedElement) -> (GTKWidget, GTKMenu, String)? {
        let shown: [(GTKWidget, GTKMenu)] = frames().compactMap { frame in frame.mainMenu.map { ($0.button, $0.menu) } }
            + (renderer?.views(GTKView.self) ?? []).compactMap { view in view.contextMenu.map { (view.widget, $0.menu) } }
        for (widget, menu) in shown {
            if let name = menu.items.first(where: { $0.value() === element })?.key { return (widget, menu, name) }
        }
        return nil
    }

    /// The entries `model` holds as the drivers say them: captions, "!" before one whose action cannot run, "-"
    /// between sections, a submenu's entries in brackets after its caption, ";" between.
    static func said(_ model: UnsafeMutablePointer<GMenuModel>, actions: UnsafeMutablePointer<GSimpleActionGroup>) -> String {
        var words: [String] = []
        for index in 0..<g_menu_model_get_n_items(model) {
            if let section = g_menu_model_get_item_link(model, index, "section") {
                if !words.isEmpty { words.append("-") }
                words.append(said(section, actions: actions))
                g_object_unref(UnsafeMutableRawPointer(section))
                continue
            }
            let label = attribute(model, index, "label") ?? ""
            if let submenu = g_menu_model_get_item_link(model, index, "submenu") {
                let opens = (attribute(model, index, "submenu-action") ?? "").split(separator: ".").last.map(String.init)
                let enabled = opens.map { g_action_group_get_action_enabled(OpaquePointer(actions), $0) != 0 } ?? true
                words.append((enabled ? "" : "!") + label + "[" + said(submenu, actions: actions) + "]")
                g_object_unref(UnsafeMutableRawPointer(submenu))
                continue
            }
            let action = (attribute(model, index, "action") ?? "").split(separator: ".").last.map(String.init) ?? ""
            let enabled = g_action_group_get_action_enabled(OpaquePointer(actions), action) != 0
            words.append((enabled ? "" : "!") + label)
        }
        return words.joined(separator: ";")
    }

    /// A string attribute of the item at `index` of `model`; nil where it has none.
    private static func attribute(_ model: UnsafeMutablePointer<GMenuModel>, _ index: Int32, _ name: String) -> String? {
        guard let value = g_menu_model_get_item_attribute_value(model, index, name, nil) else { return nil }
        defer { g_variant_unref(value) }
        return String(cString: g_variant_get_string(value, nil))
    }
}
