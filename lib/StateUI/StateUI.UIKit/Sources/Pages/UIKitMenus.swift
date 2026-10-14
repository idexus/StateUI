// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// UIKit's menus, built from the host layer's walk (`MenuEntry`): an action for each item, which tells its element when
/// chosen and stands on the element, a submenu for each menu, and the entries between two separators a group of
/// their own, as UIKit parts a menu.
/// Design: docs/design/platforms/uikit/pages.md#menus
@MainActor
enum UIKitMenus {
    /// A menu titled `title` holding `entries`; out of reach, every entry in it is, as UIKit holds no menu out of reach
    /// itself.
    static func menu(
        _ entries: [MenuEntry], title: String = "", identifier: UIMenu.Identifier? = nil, inReach: Bool = true
    ) -> UIMenu {
        var groups: [[UIMenuElement]] = [[]]
        for entry in entries {
            switch entry.kind {
            case .separator: groups.append([])
            case .item: groups[groups.count - 1].append(action(entry, inReach: inReach))
            case .submenu:
                groups[groups.count - 1].append(
                    menu(entry.entries, title: entry.title, identifier: nil, inReach: inReach && entry.isEnabled))
            }
        }
        let parted = groups.filter { !$0.isEmpty }
        let children: [UIMenuElement] = parted.count <= 1
            ? parted.first ?? []
            : parted.map { UIMenu(title: "", options: .displayInline, children: $0) }
        let built = identifier.map { UIMenu(title: title, identifier: $0, children: children) }
            ?? UIMenu(title: title, children: children)
        if !inReach { outOfReach.add(built) }
        return built
    }

    /// The menus held out of reach - each by its entries, as UIKit holds no menu out of reach itself.
    private static let outOfReach = NSHashTable<UIMenu>.weakObjects()

    /// An entry's action - a key command where it states a shortcut, which UIKit shows beside its words and sends up
    /// the responder chain to the window's root, chosen or pressed.
    private static func action(_ entry: MenuEntry, inReach: Bool) -> UIMenuElement {
        let element = entry.element?.uiKit
        var attributes: UIMenuElement.Attributes = []
        if !entry.isEnabled || !inReach { attributes.insert(.disabled) }
        if entry.isDestructive { attributes.insert(.destructive) }
        if let shortcut = entry.keyboardShortcut, let mount = entry.element?.mount {
            let command = UIKitKeys.entry(
                shortcut, title: entry.title, image: entry.icon.flatMap(UIKitRenderer.image),
                action: #selector(UIKitRootViewController.chooseMenuEntry(_:)), entry: mount)
            command.attributes = attributes
            command.state = entry.isOn == true ? .on : .off
            command.accessibilityIdentifier = entry.identifier
            element?.menuCommand = command
            element?.menuAction = nil
            return command
        }
        element?.menuCommand = nil
        let action = UIAction(
            title: entry.title, image: entry.icon.flatMap(UIKitRenderer.image),
            identifier: element?.actionIdentifier
        ) { [weak element] _ in element?.choose() }
        action.attributes = attributes
        action.state = entry.isOn == true ? .on : .off
        action.accessibilityIdentifier = entry.identifier
        element?.menuAction = action
        return action
    }

    /// A menu as the suite writes it: each entry by its caption, "!" before one that cannot be chosen, "-" between
    /// two groups, a submenu's entries in brackets after its caption, ";" between; `identified`, each action and menu
    /// with its identifier after an "@", and a key command with its shortcut and the entry it is known by.
    static func said(_ elements: [UIMenuElement], identified: Bool = false) -> String {
        var parts: [String] = []
        for element in elements {
            if let action = element as? UIAction {
                parts.append((action.attributes.contains(.disabled) ? "!" : "") + action.title
                    + (identified ? "@" + action.identifier.rawValue : ""))
            } else if let command = element as? UIKeyCommand {
                let shortcut = UIKitKeys.shortcut(of: command).map { " \($0)" } ?? ""
                let entry = (command.propertyList as? NSNumber).map { "@\($0)" } ?? ""
                parts.append((command.attributes.contains(.disabled) ? "!" : "") + command.title
                    + (identified ? shortcut + entry : ""))
            } else if let menu = element as? UIMenu {
                let children = said(menu.children, identified: identified)
                if menu.options.contains(.displayInline) {
                    if !parts.isEmpty { parts.append("-") }
                    parts.append(children)
                } else {
                    parts.append((outOfReach.contains(menu) ? "!" : "") + menu.title
                        + (identified ? "@" + menu.identifier.rawValue : "") + "[" + children + "]")
                }
            }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ";")
    }

    /// The identifier of UIKit's own menu that `standard` stands for.
    static func identifier(_ standard: StandardMenu) -> UIMenu.Identifier {
        switch standard {
        case .file: .file
        case .edit: .edit
        case .view: .view
        case .window: .window
        case .help: .help
        }
    }
}
#endif
