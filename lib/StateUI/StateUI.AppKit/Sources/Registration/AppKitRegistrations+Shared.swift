// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// What this host realizes around every view rather than inside a registration:
    /// the room, the drawing and turning, the accessibility words, the gestures.
    /// Design: docs/design/platforms/appkit/registrations.md#shared-members
    static func shared(_ registry: Registry<NSView>) {
        registry.everyElementMeetsAssistiveTechnology()
        registry.everyElementTakesItsPlace()
        registry.everyElementIsDrawnOverItsPlace()
        registry.everyElementHearsTheUser()
        registry.everyElementDragsAndDrops()
        registry.everyElementRealizes(VisualElementContract.ignoresInput)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(LayoutContract.letsInputThrough)
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }
}

#endif
