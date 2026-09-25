// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// Where the view stands: the place its layout gives it, and the transform drawn over that place.
extension GTKView {
    /// How deep the allocations under way stand: a place written inside one lands at once.
    static var allocating = 0

    /// Places the widget at `place` in its parent: at once inside an allocation, and between allocations by asking
    /// the layout for one. The size is whole pixels, no smaller than the widget's least.
    /// Design: docs/design/platforms/gtk/layout.md#a-place-between-passes
    func layout(_ place: Rect) {
        placed = place
        guard Self.allocating > 0 else {
            if let placingLayout { gtk_widget_queue_allocate(placingLayout.widget) }
            return
        }

        var least: Int32 = 0
        var natural: Int32 = 0
        gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &least, &natural, nil, nil)
        let width = max(least, Int32(place.width.rounded()))
        gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, width, &least, &natural, nil, nil)
        let height = max(least, Int32(place.height.rounded()))
        gtk_widget_allocate(widget, width, height, -1, allocation(at: place, width: Double(width), height: Double(height)))
    }

    /// Moves, turns and scales the view where its layout put it; drawn in the layout's next allocation.
    func setTransform(_ transform: HostDrawingTransform) {
        guard transform != self.transform else { return }
        self.transform = transform
        if let placingLayout { gtk_widget_queue_allocate(placingLayout.widget) }
    }

    /// The place's corner, then the translation, then the turn and the scale about the pivot.
    /// Design: docs/design/platforms/gtk/motion.md#moved-turned-and-scaled
    private func allocation(at place: Rect, width: Double, height: Double) -> OpaquePointer? {
        var corner = graphene_point_t(
            x: Float(place.x + transform.translationX), y: Float(place.y + transform.translationY))
        var moved = gsk_transform_translate(nil, &corner)
        guard transform.rotation != 0 || transform.scaleX != 1 || transform.scaleY != 1 else { return moved }

        var pivot = graphene_point_t(x: Float(transform.pivotX * width), y: Float(transform.pivotY * height))
        var back = graphene_point_t(x: -pivot.x, y: -pivot.y)
        moved = gsk_transform_translate(moved, &pivot)
        moved = gsk_transform_rotate(moved, Float(transform.rotation))
        moved = gsk_transform_scale(moved, Float(transform.scaleX), Float(transform.scaleY))
        return gsk_transform_translate(moved, &back)
    }
}

extension GTKView: PlacedView {
    /// Where the view stands in its parent - where the host last placed it, or where GTK has it.
    var placedFrame: Rect {
        get { placed ?? laidOutFrame }
        set { layout(newValue) }
    }
}
