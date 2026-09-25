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

    /// The place's corner, then a placing run's drawing, then the view's own transform: each the core's matrix
    /// for the size allocated, the view's own applied first.
    /// Design: docs/design/platforms/gtk/motion.md#moved-turned-and-scaled
    private func allocation(at place: Rect, width: Double, height: Double) -> OpaquePointer? {
        var corner = graphene_point_t(x: Float(place.x), y: Float(place.y))
        var drawn = gsk_transform_translate(nil, &corner)
        for each in [placedDrawing, transform] {
            guard let each, !each.isIdentity else { continue }
            var matrix = Self.graphene(each.matrix(width: width, height: height))
            drawn = gsk_transform_matrix(drawn, &matrix)
        }
        return drawn
    }

    /// The core's matrix as graphene's: both act on row vectors, entry for entry.
    private static func graphene(_ matrix: HostMatrix) -> graphene_matrix_t {
        var native = graphene_matrix_t()
        let entries = [
            matrix.m11, matrix.m12, matrix.m13, matrix.m14, matrix.m21, matrix.m22, matrix.m23, matrix.m24,
            matrix.m31, matrix.m32, matrix.m33, matrix.m34, matrix.m41, matrix.m42, matrix.m43, matrix.m44,
        ].map { Float($0) }
        _ = entries.withUnsafeBufferPointer { graphene_matrix_init_from_float(&native, $0.baseAddress) }
        return native
    }
}

extension GTKView: PlacedView {
    /// Where the view stands in its parent - where the host last placed it, or where GTK has it.
    var placedFrame: Rect {
        get { placed ?? laidOutFrame }
        set { layout(newValue) }
    }
}
