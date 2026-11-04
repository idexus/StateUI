// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

extension NSView {
    /// Whether the view is drawn away from its frame: moved, turned or sized by its element's drawing.
    var isDrawnAway: Bool {
        AppKitViewDrawing.of(self)?.drawsAway == true
    }

    /// Whether this view or an ancestor is drawn away from its frame.
    var standsDrawnAway: Bool {
        var view: NSView? = self
        while let each = view {
            if each.isDrawnAway { return true }
            view = each.superview
        }
        return false
    }

    /// What of the view AppKit is to draw: the whole of it where it or an ancestor stands under a transform, which
    /// AppKit leaves out of what it takes for `visible`; `visible` otherwise.
    /// Design: docs/design/platforms/appkit/views.md#a-view-under-a-transform
    func drawnRect(visible: NSRect) -> NSRect {
        standsDrawnAway ? bounds : visible
    }

    /// Where `point`, in the window, lands in the view's own coordinates under what its drawing and its ancestors'
    /// move - which `convert(_:from:)` leaves out: the point taken down from the window's content, each drawing
    /// undone in turn; by the frames alone where none draws away. Nil where a drawing on the way flattens its view:
    /// no point lands in it.
    /// Design: docs/design/platforms/appkit/input.md#a-view-drawn-away-from-its-frame
    func drawnPoint(fromWindow point: NSPoint) -> NSPoint? {
        guard standsDrawnAway else { return convert(point, from: nil) }
        var views: [NSView] = []
        var each: NSView? = self
        while let view = each {
            views.append(view)
            each = view.superview
        }
        var landed = point
        for view in views.reversed() {
            guard let undone = view.undrawnLocal(view.convert(landed, from: view.superview)) else { return nil }
            landed = undone
        }
        return landed
    }

    /// `point`, in the superview's coordinates, as the frame alone would map it to where it lands in the view under
    /// its drawing: what `hitTest(_:)` takes. Nil where the drawing flattens the view: nothing lands in it.
    /// Design: docs/design/platforms/appkit/input.md#a-view-drawn-away-from-its-frame
    func undrawn(_ point: NSPoint) -> NSPoint? {
        guard isDrawnAway else { return point }
        return undrawnLocal(convert(point, from: superview)).map { convert($0, to: superview) }
    }

    /// `point`, in the view's own coordinates where its drawing lands, as the frame alone maps it: the drawing
    /// undone, in the view's space from its top left - the space the drawing counts in; nil where the drawing has
    /// no inverse.
    private func undrawnLocal(_ point: NSPoint) -> NSPoint? {
        guard let drawing = AppKitViewDrawing.of(self), drawing.drawsAway else { return point }
        let top = isFlipped ? point.y : bounds.height - point.y
        guard let local = drawing.undrawn(Point(Double(point.x), Double(top))) else { return nil }
        return NSPoint(x: local.x, y: isFlipped ? local.y : Double(bounds.height) - local.y)
    }
}
#endif
