// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A StateUI layout over a panel: GTK asks it to measure and allocate, and the core's arithmetic answers.
/// Design: docs/design/platforms/gtk/layout.md#a-layout-is-a-panel
@MainActor
class GTKLayoutView: GTKView {
    /// The sizes measured since GTK last asked, by the width offered.
    let measurements = MeasurementCache()

    /// The children, in order.
    private(set) var items: [GTKLayoutItem] = []

    /// The direction the children are laid out in, the element's; a turn lays them out again.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { invalidateMeasurements() } }
    }

    /// The views the panel holds, in the order it draws them, back to front.
    private var held: [GTKView] = []

    init() {
        super.init { number in GTKPanel.make(number: number) }
    }

    /// Puts `items` in the panel, in order, where they differ from the children it holds; whether they did.
    @discardableResult
    func setItems(_ items: [GTKLayoutItem]) -> Bool {
        guard items.count != self.items.count
            || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        else { return false }

        self.items = items
        for item in items { item.view.placingLayout = self }
        setChildren(items.map(\.view))
        invalidateMeasurements()
        return true
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
    func measure(across: Bool, forSize: Int32) -> Double {
        forgetMeasurements()
        if across {
            return measurements.size(offering: nil) { contentSize(width: nil) }.width
        }
        let offered: Double? = forSize >= 0 ? Double(forSize) : nil
        return measurements.size(offering: offered) { contentSize(width: offered) }.height
    }

    /// Answers GTK's allocation: places every child in `width` by `height`, inside the allocation.
    func allocate(width: Double, height: Double) {
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
