// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The cell of StateUI's AppKit button: its words and picture stand inside its padding and clear of the room kept at
/// its trailing edge for its menu's arrow, its bezel the whole button's; and it tells assistive technology how its
/// menu opens.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
@MainActor
final class AppKitButtonCell: NSButtonCell {
    /// The room kept at the trailing edge for a menu's arrow, in points.
    var arrowRoom: CGFloat = 0

    /// The room the tree keeps between the button's edges and what it shows, in points.
    var padding = NSEdgeInsetsZero {
        didSet { if !NSEdgeInsetsEqual(padding, oldValue) { controlView?.needsDisplay = true } }
    }

    /// `rect` inside the padding, without the room kept for the arrow.
    private func clear(of rect: NSRect) -> NSRect {
        var inside = NSRect(
            x: rect.minX + padding.left, y: rect.minY + padding.top,
            width: max(0, rect.width - padding.left - padding.right),
            height: max(0, rect.height - padding.top - padding.bottom))
        guard arrowRoom > 0 else { return inside }
        inside.size.width = max(0, inside.width - arrowRoom)
        if controlView?.userInterfaceLayoutDirection == .rightToLeft { inside.origin.x += arrowRoom }
        return inside
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: clear(of: rect))
    }

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        super.imageRect(forBounds: clear(of: rect))
    }

    /// A button whose click opens its menu is a menu button.
    override func accessibilityRole() -> NSAccessibility.Role? {
        (controlView as? AppKitButtonView)?.opening == .click ? .menuButton : super.accessibilityRole()
    }

    /// Assistive technology asks for the menu of a button holding one, however it opens.
    override func accessibilityPerformShowMenu() -> Bool {
        guard let button = controlView as? AppKitButtonView, button.opening != .none else {
            return super.accessibilityPerformShowMenu()
        }
        button.showMenu()
        return true
    }
}
#endif
