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
    let icon: String?
    let isEnabled: Bool
    let isDestructive: Bool
    let identifier: String?
    let perform: () -> Void

    /// The element of the item, which keeps the action UIKit was last handed.
    let element: UIKitElement?

    /// How tall a picture stands on a bar - UIKit's icon size - and on a bar made low by a phone on its side.
    static let glyphHeight = 24.0
    static let lowGlyphHeight = 18.0

    /// Its picture: one of the application's at a bar's icon size, else none.
    private var image: UIImage? {
        icon.flatMap { UIKitRenderer.glyph(named: $0, height: Self.glyphHeight) }
    }

    /// A button of the bar.
    var barItem: UIBarButtonItem {
        let item = UIBarButtonItem(primaryAction: menuAction)
        item.landscapeImagePhone = icon.flatMap { UIKitRenderer.glyph(named: $0, height: Self.lowGlyphHeight) }
        item.isEnabled = isEnabled
        item.accessibilityIdentifier = identifier
        if isDestructive { item.tintColor = .systemRed }
        return item
    }

    /// An entry of a menu.
    var menuAction: UIAction {
        let action = UIAction(title: title, image: image, identifier: element?.actionIdentifier) { _ in perform() }
        var attributes: UIMenuElement.Attributes = []
        if !isEnabled { attributes.insert(.disabled) }
        if isDestructive { attributes.insert(.destructive) }
        action.attributes = attributes
        action.accessibilityIdentifier = identifier
        element?.menuAction = action
        return action
    }
}
#endif
