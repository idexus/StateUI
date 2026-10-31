// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What every element realizes through the host layer's own rules, declared once: a host whose views take their
/// place, their drawing and the user's input by those rules names the group, not each member.
/// Design: docs/design/host/tree.md#what-every-element-realizes
extension Registry {
    /// Whether a host shows an element of `type` as unsupported: no registration of this registry makes it, and it
    /// is no page nor an arrangement of pages, no overlay nor popover, and nothing presented with no view of its own.
    /// Design: docs/design/host/tree.md#what-every-element-realizes
    public func showsUnsupported(_ type: NodeType) -> Bool {
        !realizes(type) && !NodeType.viewlessTypes.contains(type) && !NodeType.pageTypes.contains(type)
            && type != .overlay && type != .popover
    }

    /// A view's place in its layout, by the layout arithmetic: its stated sizes and bounds, its margin, its
    /// alignment, its grid cell, its area, and its depth among siblings it overlaps (`MountedElement.children`).
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
        everyElementRealizes(VisualElementContract.zIndex)
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
    /// its identifier where the toolkit gives an accessible one - `identifying` - its label and hint, its kind and
    /// value where a view may say a kind not its own - `sayingKinds` - its heading level, and whether it is met at all.
    public func everyElementMeetsAssistiveTechnology(identifying: Bool = true, sayingKinds: Bool = true) {
        if identifying { everyElementRealizes(AutomationElementContract.accessibilityIdentifier) }
        everyElementRealizes(VisualElementContract.accessibilityLabel)
        everyElementRealizes(VisualElementContract.accessibilityHint)
        if sayingKinds {
            everyElementRealizes(VisualElementContract.accessibilityRole)
            everyElementRealizes(VisualElementContract.accessibilityValue)
        }
        everyElementRealizes(VisualElementContract.accessibilityHeading)
        everyElementRealizes(VisualElementContract.isAccessibilityHidden)
        everyElementRealizes(VisualElementContract.hidesChildrenFromAccessibility)
    }

    /// The actions a screen reader offers on a view, and its steps of one that is adjustable, told to the element by
    /// the host layer's rule (`MountedElement.hear`).
    /// Design: docs/design/views/modifiers.md#a-readers-actions
    public func everyElementTakesAccessibilityActions() {
        everyElementRealizes(VisualElementContract.accessibilityActions)
        everyElementRaises(VisualElementContract.accessibilityActionPerformed)
        everyElementRaises(VisualElementContract.accessibilityAdjusted)
    }

    /// The words a view shows while the pointer rests on it, which a toolkit showing tooltips holds on any view.
    /// Design: docs/design/views/modifiers.md#a-tooltip
    public func everyElementShowsItsTooltip() {
        everyElementRealizes(VisualElementContract.tooltip)
    }

    /// Where a view stands, said as the tree reads it (`MountedElement.reportFrame`), and what the user does to it
    /// with a finger, a pen or the mouse (`MountedElement.hear`).
    public func everyElementHearsTheUser() {
        everyElementRealizes(VisualElementContract.frame)
        everyElementRaises(ViewContract.frameChanged)
        everyElementRaises(ViewContract.tapped)
        everyElementRealizes(ViewContract.tapCount)
        everyElementRaises(ViewContract.held)
        everyElementRealizes(ViewContract.holdDuration)
        everyElementRealizes(ViewContract.panXChannel)
        everyElementRealizes(ViewContract.panYChannel)
        everyElementRealizes(ViewContract.panTouchCount)
        everyElementRealizes(ViewContract.swipeDirection)
        everyElementRealizes(ViewContract.swipeThreshold)
        everyElementRaises(ViewContract.panUpdated)
        everyElementRaises(ViewContract.pinchUpdated)
        everyElementRaises(ViewContract.rotationUpdated)
        everyElementRaises(ViewContract.swiped)
        everyElementRaises(ViewContract.pointerEntered)
        everyElementRaises(ViewContract.pointerExited)
        everyElementRaises(ViewContract.pointerMoved)
        everyElementRaises(ViewContract.pointerPressed)
        everyElementRaises(ViewContract.pointerReleased)
    }

    /// The keys a view takes (`View.onKeyPressed`) reaching it as the host layer routes them (`KeyPresses`), the host
    /// offering each key of its windows before the view holding the keyboard does.
    public func everyElementTakesItsKeys() {
        everyElementRealizes(KeyboardElementContract.keysTaken)
        everyElementRaises(KeyboardElementContract.keyPressed)
    }

    /// Every element's view is dragged between views and takes what is dropped on it, by the host layer's rules
    /// (`DragAndDrop`, `DropTarget`).
    /// Design: docs/design/host/runtime.md#a-drag-between-views
    public func everyElementDragsAndDrops() {
        everyElementRealizes(ViewContract.canDrag)
        everyElementRealizes(ViewContract.dragText)
        everyElementRealizes(ViewContract.allowsDrop)
        everyElementRaises(ViewContract.dragStarting)
        everyElementRaises(ViewContract.dragEnded)
        everyElementRaises(ViewContract.dragOver)
        everyElementRaises(ViewContract.dragLeave)
        everyElementRaises(ViewContract.drop)
    }

    /// Every element's view takes files dropped on it from the system, of the kinds it lists (`DragAndDrop.taken`).
    /// Design: docs/design/host/runtime.md#files-dropped-on-a-view
    public func everyElementTakesDroppedFiles() {
        everyElementRealizes(ViewContract.droppedFileTypes)
        everyElementRaises(ViewContract.filesDropped)
    }
}
