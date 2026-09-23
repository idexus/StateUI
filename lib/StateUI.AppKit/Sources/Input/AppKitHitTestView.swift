// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A StateUI-owned AppKit surface: StateUI's input transparency, and a press
/// assistive technology reaches as a click does.
/// Design: docs/design/platforms/appkit/input.md#hit-testing
@MainActor
class AppKitHitTestView: NSView {
    private var ignoresInput = false
    private var transparencyReachesChildren = true

    /// What an accessibility press performs, while the element answers a tap.
    var pressAction: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        guard let pressAction else { return false }
        pressAction()
        return true
    }

    /// An element that answers a tap takes the first click into an inactive window.
    /// Design: docs/design/platforms/appkit/input.md#the-first-click
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        pressAction != nil || super.acceptsFirstMouse(for: event)
    }

    func applyInputTransparency(_ transparent: Bool, cascades: Bool) {
        ignoresInput = transparent
        transparencyReachesChildren = cascades
    }

    var inputTransparencyForTesting: (transparent: Bool, cascades: Bool) {
        (ignoresInput, transparencyReachesChildren)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard ignoresInput else { return super.hitTest(point) }
        guard !transparencyReachesChildren else { return nil }

        let target = super.hitTest(point)
        return target === self ? nil : target
    }
}

#endif
