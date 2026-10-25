// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One of a page's actions: its words, its picture, whether it can be taken or destroys something, the identifier
/// automation finds it by, and what taking it does.
@MainActor
struct UIKitBarAction {
    let title: String
    let icon: HostPicture?
    let isEnabled: Bool
    let isDestructive: Bool
    let identifier: String?
    let perform: () -> Void

    /// The element of the item, which keeps the action UIKit was last handed.
    let element: UIKitElement?

    /// A setting's state, on or off; nil for an action.
    var isOn: Bool? = nil

    /// The menu its button opens; nil for an action holding none.
    var menu: Menu? = nil

    /// The menu a bar's button opens: how it opens, its entries, and what it offers behind the overflow
    /// (`ButtonMenu`).
    struct Menu {
        let opening: ButtonMenuOpening
        let entries: [MenuEntry]
        let inOverflow: [MenuEntry]
    }

    /// How tall a picture stands on a bar - the size a glass circle holds its symbol at, room around it - and on a
    /// bar made low by a phone on its side.
    static let glyphHeight = 20.0
    static let lowGlyphHeight = 18.0

    /// Its picture: one of the application's at a bar's icon size, else none.
    private var image: UIImage? {
        icon.flatMap { UIKitRenderer.glyph($0, height: Self.glyphHeight) }
    }

    /// Everything its button shows and the element it answers: a bar keeps its buttons while its actions say the same.
    struct Said: Equatable {
        let title: String
        let icon: HostPicture?
        let isEnabled: Bool
        let isDestructive: Bool
        let identifier: String?
        let mount: UInt64?
        let isOn: Bool?
        var opening: ButtonMenuOpening = .none
        var menu: [MenuEntry.Said] = []
        var inOverflow: [MenuEntry.Said] = []
    }

    var said: Said {
        Said(
            title: title, icon: icon, isEnabled: isEnabled, isDestructive: isDestructive, identifier: identifier,
            mount: element?.element.mount, isOn: isOn, opening: menu?.opening ?? .none,
            menu: menu?.entries.map(\.said) ?? [], inOverflow: menu?.inOverflow.map(\.said) ?? [])
    }

    /// A button of the bar, in `tint` - a painted bar's words, nil for the bar's own - or red where it destroys
    /// something.
    func barItem(tint: UIColor?) -> UIBarButtonItem {
        let item: UIBarButtonItem
        if let menu {
            // Its tap opens the menu where the button has no click of its own, else holding it does: UIKit's bar
            // offers no arrow part, so a split stands as held.
            // Design: docs/design/platforms/uikit/pages.md#the-bar
            let opened = UIKitMenus.menu(menu.entries, identifier: element?.menuIdentifier)
            item = menu.opening == .click
                ? UIBarButtonItem(title: title, image: image, primaryAction: nil, menu: opened)
                : UIBarButtonItem(primaryAction: menuAction, menu: opened)
        } else {
            item = UIBarButtonItem(primaryAction: menuAction)
        }
        item.landscapeImagePhone = icon.flatMap { UIKitRenderer.glyph($0, height: Self.lowGlyphHeight) }
        item.isEnabled = isEnabled
        item.accessibilityIdentifier = identifier
        item.tintColor = self.tint(tint)
        // A setting is UIKit's two-state button: selected while on, turned over as it is chosen.
        if let isOn {
            item.changesSelectionAsPrimaryAction = true
            item.isSelected = isOn
        }
        return item
    }

    /// The color its button stands in: red where it destroys something, else `tint`.
    func tint(_ tint: UIColor?) -> UIColor? {
        isDestructive ? .systemRed : tint
    }

    /// Its entry behind the bar's overflow: its action, or, holding a menu, a submenu under its words.
    var overflowEntry: UIMenuElement {
        menu.map { UIKitMenus.menu($0.inOverflow, title: title) } ?? menuAction
    }

    /// An entry of a menu. Its handler takes `perform` alone: the element keeps the action, which would keep the element
    /// and its menu's entries taking the whole action.
    var menuAction: UIAction {
        let action = UIAction(title: title, image: image, identifier: element?.actionIdentifier) { [perform] _ in
            perform()
        }
        var attributes: UIMenuElement.Attributes = []
        if !isEnabled { attributes.insert(.disabled) }
        if isDestructive { attributes.insert(.destructive) }
        action.attributes = attributes
        if let isOn { action.state = isOn ? .on : .off }
        action.accessibilityIdentifier = identifier
        element?.menuAction = action
        return action
    }
}
#endif
