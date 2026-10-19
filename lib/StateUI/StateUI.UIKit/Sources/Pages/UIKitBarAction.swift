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
    }

    var said: Said {
        Said(
            title: title, icon: icon, isEnabled: isEnabled, isDestructive: isDestructive, identifier: identifier,
            mount: element?.element.mount)
    }

    /// A button of the bar, in `tint` - a painted bar's words, nil for the bar's own - or red where it destroys
    /// something.
    func barItem(tint: UIColor?) -> UIBarButtonItem {
        let item = UIBarButtonItem(primaryAction: menuAction)
        item.landscapeImagePhone = icon.flatMap { UIKitRenderer.glyph($0, height: Self.lowGlyphHeight) }
        item.isEnabled = isEnabled
        item.accessibilityIdentifier = identifier
        item.tintColor = self.tint(tint)
        return item
    }

    /// The colour its button stands in: red where it destroys something, else `tint`.
    func tint(_ tint: UIColor?) -> UIColor? {
        isDestructive ? .systemRed : tint
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
