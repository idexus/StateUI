// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A GTK widget Swift holds, and the number its signals name it by.
/// Design: docs/design/platforms/gtk/c-api.md#a-view-and-its-number
@MainActor
class GTKView {
    /// The widget, held until this is released.
    let widget: GTKWidget

    /// The number the widget's signals hand back.
    let number: Int64

    private static var nextNumber: Int64 = 0
    private static var live: [Int64: Weak] = [:]

    /// Takes the next number and holds the widget `make` makes, handed that number.
    init(_ make: (_ number: Int64) -> GTKWidget?) {
        Self.nextNumber += 1
        number = Self.nextNumber
        guard let widget = make(number) else { fatalError("GTK made no widget") }
        self.widget = widget
        g_object_ref_sink(widget)
        Self.live[number] = Weak(self)
    }

    isolated deinit {
        Self.live[number] = nil
        if gtk_widget_get_parent(widget) != nil { gtk_widget_unparent(widget) }
        g_object_unref(widget)
    }

    /// The live view a signal names; nil once it has left.
    static func find(_ number: Int64) -> GTKView? {
        live[number]?.view
    }

    /// How many views Swift holds - what a test counts to see every one let go.
    static var liveCount: Int { live.count }

    /// Connects `handler` to the widget's `signal`, handing it this view's number.
    func connect(_ signal: String, _ handler: GTKSignalHandler) {
        connectSignal(UnsafeMutableRawPointer(widget), signal, number: number, handler)
    }

    // MARK: - What every view takes

    func setShown(_ shown: Bool) {
        gtk_widget_set_visible(widget, shown ? 1 : 0)
    }

    func setOpacity(_ opacity: Double) {
        gtk_widget_set_opacity(widget, opacity)
    }

    func setEnabled(_ enabled: Bool) {
        gtk_widget_set_sensitive(widget, enabled ? 1 : 0)
    }

    /// Asks GTK to measure this widget again, and every widget above it.
    func invalidateMeasure() {
        gtk_widget_queue_resize(widget)
    }

    /// The widget's size for the room offered, in logical pixels; nil offers any. Its natural width, no wider
    /// than offered nor narrower than its least, and its natural height for that width.
    /// Design: docs/design/platforms/gtk/layout.md#measuring-a-widget
    func measure(width: Double?, height: Double?) -> LayoutSize {
        var least: Int32 = 0
        var natural: Int32 = 0
        gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &least, &natural, nil, nil)
        var measuredWidth = Double(natural)
        if let width { measuredWidth = max(Double(least), min(measuredWidth, width.rounded(.down))) }

        gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, Int32(measuredWidth), &least, &natural, nil, nil)
        return LayoutSize(width: measuredWidth, height: Double(natural))
    }

    /// Places the widget at `place` in its parent - only inside the parent's allocation. The size is whole pixels,
    /// no smaller than the widget's least; the position may fall between them.
    /// Design: docs/design/platforms/gtk/layout.md#a-layout-is-a-panel
    func layout(_ place: Rect) {
        var least: Int32 = 0
        var natural: Int32 = 0
        gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &least, &natural, nil, nil)
        let width = max(least, Int32(place.width.rounded()))
        gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, width, &least, &natural, nil, nil)
        let height = max(least, Int32(place.height.rounded()))

        var origin = graphene_point_t(x: Float(place.x), y: Float(place.y))
        gtk_widget_allocate(widget, width, height, -1, gsk_transform_translate(nil, &origin))
    }

    /// Where GTK laid the widget out in its parent, in logical pixels, its CSS box included.
    var laidOutFrame: Rect {
        var bounds = graphene_rect_t()
        guard let parent = gtk_widget_get_parent(widget), gtk_widget_compute_bounds(widget, parent, &bounds) != 0
        else { return Rect(x: 0, y: 0, width: 0, height: 0) }
        return Rect(
            x: Double(bounds.origin.x), y: Double(bounds.origin.y),
            width: Double(bounds.size.width), height: Double(bounds.size.height))
    }

    /// The user clicked the view.
    func clicked() {}

    /// The element left the tree: the view lets go of everything that would call back into it.
    func detach() {}

    private struct Weak {
        weak var view: GTKView?

        init(_ view: GTKView) { self.view = view }
    }
}
