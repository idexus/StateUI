// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A StateUI layout over a panel: GTK asks it to measure and allocate, and the core's arithmetic answers; it draws
/// its own box behind its children.
/// Design: docs/design/platforms/gtk/layout.md#a-layout-is-a-panel
@MainActor
class GTKLayoutView: GTKPanelView {
    /// The sizes measured since GTK last asked, by the width offered.
    let measurements = MeasurementCache()

    /// The children, in order.
    private(set) var items: [GTKLayoutItem] = []

    /// The direction the children are laid out in, the element's; a turn lays them out again.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { invalidateMeasurements() } }
    }

    /// The layout's own box: what fills it, its outline, its shape and whether it cuts what it shows.
    struct Box: Equatable {
        var fill = GTKBrush.none
        var stroke = GTKBrush.none
        var width = 0.0
        var outline = ContainerShape.rectangle
        var clips = false
    }

    /// The box as the element says it.
    private(set) var box = Box()

    /// The views the panel holds, in the order it draws them, back to front.
    private var held: [GTKView] = []

    /// Puts `items` in the panel, in order, where they differ from the children it holds; whether they did.
    @discardableResult
    func setItems(_ items: [GTKLayoutItem]) -> Bool {
        guard items.count != self.items.count
            || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        else { return false }

        self.items = items
        for item in items { item.view.placingLayout = self }
        setChildren(heldViews())
        invalidateMeasurements()
        return true
    }

    /// The views the panel holds, in the order it draws them: every child's, unless a layout orders them.
    func heldViews() -> [GTKView] {
        items.map(\.view)
    }

    /// What fills the box: a colour or a brush; nil for nothing.
    func setBackground(_ value: HostValue?) {
        box.fill = GTKBrush(value)
        gtk_widget_queue_draw(widget)
    }

    /// The box's outline, its shape, and whether it cuts what the layout shows to that shape.
    func setOutline(stroke: HostValue?, width: Double?, shape: HostValue?, clips: Bool) {
        box.stroke = GTKBrush(stroke)
        box.width = BoxArithmetic.outlineWidth(stroke: stroke, width: width)
        box.outline = BoxArithmetic.outline(shape)
        box.clips = clips
        gtk_widget_set_overflow(widget, clips ? GTK_OVERFLOW_HIDDEN : GTK_OVERFLOW_VISIBLE)
        gtk_widget_queue_draw(widget)
    }

    /// Draws the box - the fill inside the outline, the outline's stroke inside its edge - then the children, cut to
    /// the outline where the box clips.
    /// Design: docs/design/platforms/gtk/drawing.md#a-layouts-box
    override func draw(_ snapshot: OpaquePointer, width: Double, height: Double) {
        let bounds = graphene_rect_t(
            origin: graphene_point_t(x: 0, y: 0), size: graphene_size_t(width: Float(width), height: Float(height)))
        var outline = box.outline.rounded(bounds)
        let rounded = box.outline != .rectangle

        if box.fill != .none {
            if rounded { gtk_snapshot_push_rounded_clip(snapshot, &outline) }
            box.fill.paint(snapshot, bounds)
            if rounded { gtk_snapshot_pop(snapshot) }
        }
        if box.width > 0, let color = box.stroke.firstColor {
            var widths: [Float] = Array(repeating: Float(box.width), count: 4)
            var colors: [GdkRGBA] = Array(repeating: color, count: 4)
            gtk_snapshot_append_border(snapshot, &outline, &widths, &colors)
        }

        if box.clips { gtk_snapshot_push_rounded_clip(snapshot, &outline) }
        drawChildren(snapshot)
        if box.clips { gtk_snapshot_pop(snapshot) }
    }

    /// Holds `views` in the panel in this order, the one it draws them in.
    func setChildren(_ views: [GTKView]) {
        guard views.count != held.count || !zip(views, held).allSatisfy({ $0 === $1 }) else { return }

        for gone in held where !views.contains(where: { $0 === gone }) && gtk_widget_get_parent(gone.widget) == widget {
            gtk_widget_unparent(gone.widget)
        }
        var previous: GTKWidget?
        for view in views {
            if let parent = gtk_widget_get_parent(view.widget), parent != widget { gtk_widget_unparent(view.widget) }
            gtk_widget_insert_after(view.widget, widget, previous)
            previous = view.widget
        }
        held = views
    }

    /// Forgets the kept sizes and asks GTK to measure again.
    func invalidateMeasurements() {
        forgetMeasurements()
        invalidateMeasure()
    }

    /// Forgets the sizes this layout keeps.
    func forgetMeasurements() {
        measurements.invalidate()
    }

    /// Answers GTK's measure: the natural width across, or the height for the width `forSize`, every child
    /// measured again. The least is nothing: StateUI's arithmetic decides what fits.
    /// Design: docs/design/platforms/gtk/layout.md#measured-per-axis
    override func measure(across: Bool, forSize: Int32) -> Double {
        forgetMeasurements()
        if across {
            return measurements.size(offering: nil) { contentSize(width: nil) }.width
        }
        let offered: Double? = forSize >= 0 ? Double(forSize) : nil
        return measurements.size(offering: offered) { contentSize(width: offered) }.height
    }

    /// Answers GTK's allocation: places every child in `width` by `height`, inside the allocation.
    override func allocate(width: Double, height: Double) {
        GTKView.allocating += 1
        defer { GTKView.allocating -= 1 }
        arrange(in: Rect(x: 0, y: 0, width: width, height: height))
    }

    /// The room the children take for the width offered.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// Places the children in `bounds`.
    func arrange(in bounds: Rect) {}
}
