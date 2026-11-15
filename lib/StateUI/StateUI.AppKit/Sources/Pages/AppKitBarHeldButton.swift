// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A button on the bar at a page's foot whose menu opens held: an accessory bar control as its neighbors, no arrow,
/// its click its own action and its menu opened by a press held past the hold's delay (`AppKitHeldPress`) or by
/// assistive technology asking for it.
/// Design: docs/design/platforms/appkit/runtime.md#the-bar-at-the-foot
@MainActor
final class AppKitBarHeldButton: NSButton {
    /// The menu a held press opens.
    let offered = NSMenu()

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return super.mouseDown(with: event) }
        highlight(true)
        let end = AppKitHeldPress.follow(on: self)
        highlight(false)
        switch end {
        case .click: sendAction(action, to: target)
        case .held: showMenu()
        case .away: break
        }
    }

    override func accessibilityPerformShowMenu() -> Bool {
        showMenu()
        return true
    }

    /// Opens the menu under the button, at least as wide - none while the button is disabled.
    private func showMenu() {
        guard isEnabled else { return }
        offered.minimumWidth = bounds.width
        offered.popUp(positioning: nil, at: NSPoint(x: 0, y: isFlipped ? bounds.maxY + 2 : bounds.minY - 2), in: self)
    }
}

#endif
