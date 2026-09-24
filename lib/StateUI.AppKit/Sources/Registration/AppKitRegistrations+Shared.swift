// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

extension AppKitRegistrations {
    /// What this host realizes around every view rather than inside a registration:
    /// the room, the drawing and turning, the accessibility words, the gestures.
    /// Design: docs/design/platforms/appkit/registrations.md#shared-members
    static func shared(_ registry: Registry<NSView>) {
        registry.everyElementRealizes(PropertyContainerContract.accessibilityIdentifier)
        registry.everyElementRealizes(TintElementContract.tint)

        registry.everyElementRealizes(VisualElementContract.accessibilityHeadingLevel)
        registry.everyElementRealizes(VisualElementContract.accessibilityHint)
        registry.everyElementRealizes(VisualElementContract.accessibilityLabel)
        registry.everyElementRealizes(VisualElementContract.automationExcludedWithChildren)
        registry.everyElementRealizes(VisualElementContract.frame)
        registry.everyElementRealizes(VisualElementContract.height)
        registry.everyElementRealizes(VisualElementContract.ignoresInput)
        registry.everyElementRealizes(VisualElementContract.isAccessibilityHidden)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.maximumHeight)
        registry.everyElementRealizes(VisualElementContract.maximumWidth)
        registry.everyElementRealizes(VisualElementContract.minimumHeight)
        registry.everyElementRealizes(VisualElementContract.minimumWidth)
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.pivotX)
        registry.everyElementRealizes(VisualElementContract.pivotY)
        registry.everyElementRealizes(VisualElementContract.rotation)
        registry.everyElementRealizes(VisualElementContract.rotationX)
        registry.everyElementRealizes(VisualElementContract.rotationY)
        registry.everyElementRealizes(VisualElementContract.scale)
        registry.everyElementRealizes(VisualElementContract.scaleX)
        registry.everyElementRealizes(VisualElementContract.scaleY)
        registry.everyElementRealizes(VisualElementContract.translationX)
        registry.everyElementRealizes(VisualElementContract.translationY)
        registry.everyElementRealizes(VisualElementContract.width)

        registry.everyElementRealizes(ViewContract.area)
        registry.everyElementRealizes(ViewContract.gridColumn)
        registry.everyElementRealizes(ViewContract.gridColumnSpan)
        registry.everyElementRealizes(ViewContract.gridRow)
        registry.everyElementRealizes(ViewContract.gridRowSpan)
        registry.everyElementRealizes(ViewContract.horizontalAlignment)
        registry.everyElementRealizes(ViewContract.margin)
        registry.everyElementRealizes(ViewContract.verticalAlignment)

        // What a gesture is configured with, read where the recognizers are made.
        // Design: docs/design/platforms/appkit/registrations.md#what-a-declaration-leaves-out
        registry.everyElementRealizes(ViewContract.panXChannel)
        registry.everyElementRealizes(ViewContract.panYChannel)
        registry.everyElementRealizes(ViewContract.swipeDirection)
        registry.everyElementRealizes(ViewContract.swipeThreshold)
        registry.everyElementRealizes(ViewContract.tapCount)

        registry.everyElementRealizes(LayoutContract.letsInputThrough)

        registry.everyElementRaises(ViewContract.frameChanged)
        registry.everyElementRaises(ViewContract.panUpdated)
        registry.everyElementRaises(ViewContract.pinchUpdated)
        registry.everyElementRaises(ViewContract.pointerEntered)
        registry.everyElementRaises(ViewContract.pointerExited)
        registry.everyElementRaises(ViewContract.pointerMoved)
        registry.everyElementRaises(ViewContract.pointerPressed)
        registry.everyElementRaises(ViewContract.pointerReleased)
        registry.everyElementRaises(ViewContract.swiped)
        registry.everyElementRaises(ViewContract.tapped)
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }
}

#endif
