// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A StateUI layout over a `StateUIViewGroup`: Android asks it to measure and place, and the core's arithmetic answers.
/// Design: docs/design/platforms/android/layout.md#a-layout-is-a-view-group
@MainActor
class AndroidLayoutView: AndroidView {
    /// The sizes measured for the widths offered, kept until something changes them.
    let measurements = MeasurementCache()

    /// The children, in order.
    private(set) var items: [AndroidLayoutItem] = []

    /// What the layout paints its own box with once it has an outline, a shape or a cut; nil while it has none.
    private var box: AndroidShapeDrawable?
    private var fill: HostValue?
    private var outline = Outline()

    /// The layout's outline, its shape, and whether it cuts what it holds to that shape.
    struct Outline: Equatable {
        var stroke: HostValue?
        var width: Double?
        var shape: HostValue?
        var clips = false
    }

    /// The direction the children are laid out in, the element's; a turn lays them out again, their sizes kept.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { requestLayout() } }
    }

    /// The views the group holds, in the order it draws them, back to front.
    private var held: [AndroidView] = []

    init() {
        super.init { number in
            Java.new(
                JavaAPI.viewGroupHost, JavaAPI.newViewGroupHost,
                .object(AndroidRenderer.context), .long(number))
        }
    }

    /// Puts `items` in the group, in order, where they differ from the children it holds; whether they did.
    @discardableResult
    func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        guard items.count != self.items.count
            || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        else { return false }

        let rehold = !Self.same(items.map(\.view), self.items.map(\.view))
        self.items = items
        if rehold { holdChildren() }
        invalidateMeasurements()
        return true
    }

    /// The views the group holds for its items: every item's, unless a layout shows only some.
    func heldViews() -> [AndroidView] {
        items.map(\.view)
    }

    /// Holds the views `heldViews()` answers, where they differ from those it holds.
    func holdChildren() {
        setChildren(heldViews())
    }

    /// Holds `views` in the group in this order, the one it draws them and hands them touches in.
    func setChildren(_ views: [AndroidView]) {
        guard !Self.same(views, held) else { return }

        let children = Java.array(of: JavaAPI.view, views.map(\.reference))
        Java.call(reference, JavaAPI.setChildren, .object(children))
        Java.release(local: children)
        held = views
    }

    /// The order the children are drawn and touched in, back to front, by index; nil for their own.
    private(set) var drawingOrder: [Int]?

    /// Draws the children, and hands them touches, in `order`; nil for their own order.
    func setDrawingOrder(_ order: [Int]?) {
        guard order != drawingOrder else { return }

        drawingOrder = order
        let indices = order.map { Java.ints($0.map(Int32.init)) }
        Java.call(reference, JavaAPI.setDrawingOrder, .object(indices ?? nil))
        Java.release(local: indices ?? nil)
    }

    /// The background, painted on the layout's shape where it has one.
    override func setBackground(_ value: HostValue?) {
        fill = value
        paintBox()
    }

    /// The layout's own box: a plain colour where it has no outline, shape or cut, and a drawable on its shape
    /// where it has.
    /// Design: docs/design/platforms/android/drawing.md#a-layouts-own-box
    func setOutline(_ outline: Outline) {
        guard outline != self.outline else { return }
        self.outline = outline
        paintBox()
    }

    private func paintBox() {
        guard outline.stroke != nil || outline.shape != nil || outline.clips else {
            if box != nil { Java.call(reference, JavaAPI.setClipToOutline, .bool(false)) }
            box = nil
            return super.setBackground(fill)
        }

        let box = self.box ?? AndroidShapeDrawable()
        self.box = box
        box.setFill(fill)
        box.setStroke(outline.stroke, width: max(0, outline.width ?? 1) * density)
        box.setShape(AndroidShapeDrawable.Shape(container: outline.shape), density: density)
        showBackground(box.object)
        Java.call(reference, JavaAPI.setClipToOutline, .bool(outline.clips))
        Java.call(reference, JavaAPI.invalidateOutline)
    }

    /// Makes the layout and everything in it deaf to touches, which go to whatever stands behind it.
    func setIgnoresInput(_ ignores: Bool) {
        Java.call(reference, JavaAPI.setIgnoresInput, .bool(ignores))
    }

    /// Forgets the kept sizes and asks Android to measure again.
    func invalidateMeasurements() {
        forgetMeasurements()
        requestLayout()
    }

    /// Forgets the sizes this layout keeps, and those of any layout inside it that no element owns.
    func forgetMeasurements() {
        measurements.invalidate()
    }

    /// Answers Android's measure: the size in pixels for the specs given.
    func measure(widthSpec: Int32, heightSpec: Int32) -> (width: Int32, height: Int32) {
        let offered = ViewConstants.mode(widthSpec) == ViewConstants.unspecified
            ? nil
            : Double(ViewConstants.size(widthSpec)) / density
        let natural = measurements.size(offering: offered) { contentSize(width: offered) }

        return (resolve(widthSpec, natural.width), resolve(heightSpec, natural.height))
    }

    /// Answers Android's layout: places every child in `width` by `height` pixels.
    func arrange(width: Int32, height: Int32) {
        arrange(in: Rect(x: 0, y: 0, width: Double(width) / density, height: Double(height) / density))
    }

    /// The room the children take for the width offered, in points.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// Places the children in `bounds`, in points.
    func arrange(in bounds: Rect) {}

    /// Whether two lists hold the same views in the same order.
    private static func same(_ left: [AndroidView], _ right: [AndroidView]) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy { $0 === $1 }
    }

    /// A measured extent within what `spec` allows.
    private func resolve(_ spec: Int32, _ natural: Double) -> Int32 {
        switch ViewConstants.mode(spec) {
        case ViewConstants.exactly: ViewConstants.size(spec)
        case ViewConstants.atMost: min(pixels(natural), ViewConstants.size(spec))
        default: pixels(natural)
        }
    }
}
