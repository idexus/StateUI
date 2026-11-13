// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A press on a button whose menu opens held: let go before the hold's delay, a click where it is let go over the
/// button; held past it, the menu's, the press going on into it. AppKit's own event tracking reads the press, with no
/// timer - for a button among views and one on the bar at a page's foot alike.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
@MainActor
enum AppKitHeldPress {
    /// How long a held press waits before it opens the menu, in seconds.
    static let delay = 0.5

    /// How a press ends: a click, let go away from the button, or held into the menu.
    enum End {
        case click, away, held
    }

    /// Follows the press just begun on `view` until it is let go or held past the delay.
    static func follow(on view: NSView) -> End {
        guard let window = view.window else { return .away }
        let until = Date(timeIntervalSinceNow: delay)
        var letGo: NSEvent?
        while letGo == nil,
              let next = window.nextEvent(
                matching: [.leftMouseUp, .leftMouseDragged], until: until, inMode: .eventTracking, dequeue: true) {
            if next.type == .leftMouseUp { letGo = next }
        }
        guard let letGo else { return .held }
        return view.drawnPoint(fromWindow: letGo.locationInWindow).map(view.bounds.contains) == true ? .click : .away
    }
}

#endif
