// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One of a page's actions: its words, its picture, whether it can be taken or destroys something, and what taking
/// it does.
@MainActor
struct UIKitBarAction {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let isDestructive: Bool
    let perform: () -> Void

    /// The element of the item, which keeps the action UIKit was last handed.
    let element: UIKitElement?

    /// Its picture: one of the application's, else none.
    private var image: UIImage? {
        icon.flatMap(UIKitRenderer.image(named:))
    }

    /// A button of the bar.
    var barItem: UIBarButtonItem {
        let item = UIBarButtonItem(primaryAction: menuAction)
        item.isEnabled = isEnabled
        if isDestructive { item.tintColor = .systemRed }
        return item
    }

    /// An entry of a menu.
    var menuAction: UIAction {
        let action = UIAction(title: title, image: image) { _ in perform() }
        var attributes: UIMenuElement.Attributes = []
        if !isEnabled { attributes.insert(.disabled) }
        if isDestructive { attributes.insert(.destructive) }
        action.attributes = attributes
        element?.menuAction = action
        return action
    }
}
#endif
