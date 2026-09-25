// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every element realizes through the host layer's own rules, declared once: a host whose views take their
/// place, their drawing and the user's input by those rules names the group, not each member.
/// Design: docs/design/host/tree.md#what-every-element-realizes
extension Registry {
    /// A view's place in its layout, by the layout arithmetic: its stated sizes and bounds, its margin, its
    /// alignment, its grid cell and its area.
    public func everyElementTakesItsPlace() {
        everyElementRealizes(VisualElementContract.width)
        everyElementRealizes(VisualElementContract.height)
        everyElementRealizes(VisualElementContract.minimumWidth)
        everyElementRealizes(VisualElementContract.minimumHeight)
        everyElementRealizes(VisualElementContract.maximumWidth)
        everyElementRealizes(VisualElementContract.maximumHeight)
        everyElementRealizes(ViewContract.margin)
        everyElementRealizes(ViewContract.horizontalAlignment)
        everyElementRealizes(ViewContract.verticalAlignment)
        everyElementRealizes(ViewContract.gridRow)
        everyElementRealizes(ViewContract.gridColumn)
        everyElementRealizes(ViewContract.gridRowSpan)
        everyElementRealizes(ViewContract.gridColumnSpan)
        everyElementRealizes(ViewContract.area)
    }

    /// A view drawn moved, turned and scaled over its place (`MountedElement.drawingTransform`).
    public func everyElementIsDrawnOverItsPlace() {
        everyElementRealizes(VisualElementContract.translationX)
        everyElementRealizes(VisualElementContract.translationY)
        everyElementRealizes(VisualElementContract.rotation)
        everyElementRealizes(VisualElementContract.rotationX)
        everyElementRealizes(VisualElementContract.rotationY)
        everyElementRealizes(VisualElementContract.scale)
        everyElementRealizes(VisualElementContract.scaleX)
        everyElementRealizes(VisualElementContract.scaleY)
        everyElementRealizes(VisualElementContract.pivotX)
        everyElementRealizes(VisualElementContract.pivotY)
    }

    /// What assistive technology meets of a view, put together by one rule (`MountedElement.accessibilityWords`):
    /// its identifier, label, hint and heading level, and whether it is met at all.
    public func everyElementMeetsAssistiveTechnology() {
        everyElementRealizes(PropertyContainerContract.accessibilityIdentifier)
        everyElementRealizes(VisualElementContract.accessibilityLabel)
        everyElementRealizes(VisualElementContract.accessibilityHint)
        everyElementRealizes(VisualElementContract.accessibilityHeadingLevel)
        everyElementRealizes(VisualElementContract.isAccessibilityHidden)
        everyElementRealizes(VisualElementContract.automationExcludedWithChildren)
    }

    /// Where a view stands, said as the tree reads it (`MountedElement.reportFrame`), and what the user does to it
    /// with a finger, a pen or the mouse (`MountedElement.hear`).
    public func everyElementHearsTheUser() {
        everyElementRealizes(VisualElementContract.frame)
        everyElementRaises(ViewContract.frameChanged)
        everyElementRaises(ViewContract.tapped)
        everyElementRealizes(ViewContract.tapCount)
        everyElementRealizes(ViewContract.panXChannel)
        everyElementRealizes(ViewContract.panYChannel)
        everyElementRealizes(ViewContract.panTouchCount)
        everyElementRealizes(ViewContract.swipeDirection)
        everyElementRealizes(ViewContract.swipeThreshold)
        everyElementRaises(ViewContract.panUpdated)
        everyElementRaises(ViewContract.pinchUpdated)
        everyElementRaises(ViewContract.swiped)
        everyElementRaises(ViewContract.pointerEntered)
        everyElementRaises(ViewContract.pointerExited)
        everyElementRaises(ViewContract.pointerMoved)
        everyElementRaises(ViewContract.pointerPressed)
        everyElementRaises(ViewContract.pointerReleased)
    }
}
