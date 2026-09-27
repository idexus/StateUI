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

    private static func action(_ entry: MenuEntry, inReach: Bool) -> UIAction {
        let element = entry.element?.uiKit
        let action = UIAction(title: entry.title, image: entry.icon.flatMap(UIKitRenderer.image(named:))) {
            [weak element] _ in element?.send(.clicked, [])
        }
        var attributes: UIMenuElement.Attributes = []
        if !entry.isEnabled || !inReach { attributes.insert(.disabled) }
        if entry.isDestructive { attributes.insert(.destructive) }
        action.attributes = attributes
        element?.menuAction = action
        return action
    }

    /// A menu as the suite writes it: each entry by its caption, "!" before one that cannot be chosen, "-" between
    /// two groups, a submenu's entries in brackets after its caption, ";" between.
    static func said(_ elements: [UIMenuElement]) -> String {
        var parts: [String] = []
        for element in elements {
            if let action = element as? UIAction {
                parts.append((action.attributes.contains(.disabled) ? "!" : "") + action.title)
            } else if let menu = element as? UIMenu {
                if menu.options.contains(.displayInline) {
                    if !parts.isEmpty { parts.append("-") }
                    parts.append(said(menu.children))
                } else {
                    parts.append((outOfReach.contains(menu) ? "!" : "") + menu.title + "[" + said(menu.children) + "]")
                }
            }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ";")
    }
}
#endif
