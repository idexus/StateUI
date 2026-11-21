// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A StateUI layout over a `StateUIViewGroup`: Android asks it to measure and place, and the host layer's arithmetic answers.
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

    /// The views of children kept as they leave: held after the items', and laid out by nobody; whether they
    /// changed since the group last held its children.
    /// Design: docs/design/platforms/android/layout.md#a-view-kept-as-it-leaves
    private(set) var leaving: [AndroidView] = []
    private var keptChanged = false

    /// The mounts of the views kept as they leave, in their order, and of every view the group presents, in the
    /// order they stand.
    private(set) var keptMounts: [UInt64] = []
    private(set) var presented: [UInt64] = []

    init() {
        super.init { number in
            Java.new(
                JavaAPI.viewGroupHost, JavaAPI.newViewGroupHost,
                .object(AndroidRenderer.context), .long(number))
        }
    }

    /// A layout over the relay's view group `make` makes - a `StateUIViewGroup` of its own kind - handed the number.
    init(making make: (_ number: Int64) -> JavaObject) {
        super.init(make)
    }

    /// A layout a hand moves sees the touches its children get before they get them: a finger on a child that
    /// answers a tap is the hand's once it moves along the layout. Any other sees those no child takes.
    /// Design: docs/design/platforms/android/controls.md#the-hand-over-a-layout
    override func watchTouches(_ hearing: Hearing) {
        Java.call(reference, JavaAPI.watchLayout, .object(listener.reference), .bool(hearing.contains(.hand)))
    }

    /// Says the views of children kept as they leave, before the items are set: the group holds them on, after
    /// its items' views, and lets go of one kept no more.
    /// Design: docs/design/platforms/android/layout.md#a-view-kept-as-it-leaves
    func keep(_ leaving: [(mount: UInt64, view: AndroidView)], presented: [UInt64]) {
        (keptMounts, self.presented) = (leaving.map(\.mount), presented)
        let views = leaving.map(\.view)
        guard !Self.same(views, self.leaving) else { return }

        self.leaving = views
        keptChanged = true
    }

    /// Puts `items` in the group, in order, where they differ from the children it holds; whether they did.
    @discardableResult
    func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        let changed = items.count != self.items.count
            || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        guard changed || keptChanged else { return false }

        let rehold = keptChanged || !Self.same(items.map(\.view), self.items.map(\.view))
        keptChanged = false
        if changed { self.items = items }
        if rehold { holdChildren() }
        if changed { invalidateMeasurements() }
        return changed
    }

    /// The views the group holds for its items: every item's, unless a layout shows only some.
    func heldViews() -> [AndroidView] {
        items.map(\.view)
    }

    /// Holds the views `heldViews()` answers and, after them, those kept as they leave, where they differ from
    /// those it holds.
    func holdChildren() {
        let own = heldViews()
        setChildren(own + leaving.filter { kept in !own.contains { $0 === kept } })
    }

    /// Holds `views` in the group in this order, the one it draws them and hands them touches in.
    func setChildren(_ views: [AndroidView]) {
        guard !Self.same(views, held) else { return }

        let children = Java.array(of: JavaAPI.view, views.map(\.outermost))
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

    /// The layout's own box: a plain color where it has no outline, shape or cut, and a drawable on its shape
    /// where it has.
    /// Design: docs/design/platforms/android/drawing.md#a-layouts-own-box
    func setOutline(_ outline: Outline) {
        guard outline != self.outline else { return }
        self.outline = outline
        paintBox()
    }

    private func paintBox() {
        let painted = fill
        guard outline.stroke != nil || outline.shape != nil || outline.clips else {
            if box != nil { Java.call(reference, JavaAPI.setClipToOutline, .bool(false)) }
            box = nil
            return super.setBackground(painted)
        }

        let box = self.box ?? AndroidShapeDrawable()
        self.box = box
        box.setFill(painted)
        box.setStroke(outline.stroke, width: outline.width, density: density)
        box.setShape(AndroidShapeDrawable.Shape(container: outline.shape), density: density)
        if let size = placedSize { box.fit(width: size.width, height: size.height) }
        showBackground(box.object)
        Java.call(reference, JavaAPI.setClipToOutline, .bool(outline.clips))
        Java.call(reference, JavaAPI.invalidateOutline)
    }

    override func sized(width: Int32, height: Int32) {
        box?.fit(width: width, height: height)
    }

    /// Lets a touch on the layout's own empty area through to whatever stands behind it; its children take theirs.
    func setLetsInputThrough(_ lets: Bool) {
        Java.call(reference, JavaAPI.setLetsInputThrough, .bool(lets))
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

    /// Answers Android's layout, which may place the layout itself: its box drawn at `width` by `height` pixels,
    /// then every child placed in it.
    final func laidOut(width: Int32, height: Int32) {
        box?.fit(width: width, height: height)
        arrange(width: width, height: height)
    }

    /// Places every child in the room the layout is bound for, else in `width` by `height` pixels.
    func arrange(width: Int32, height: Int32) {
        let room = arrangementRoom ?? LayoutSize(width: Double(width) / density, height: Double(height) / density)
        arrange(in: Rect(x: 0, y: 0, width: room.width, height: room.height))
    }

    /// The size the layout is bound for while its place travels: its children stand there meanwhile, as they will
    /// once it lands, its own box traveling around them. Design: docs/design/host/motion.md#a-layout-bound-for-a-size
    private(set) var arrangementRoom: LayoutSize?

    override func travels(to destination: Rect?) {
        arrangementRoom = destination.map { LayoutSize(width: $0.width, height: $0.height) }
    }

    /// The room the children take for the width offered, in points.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// How far below its top its first line of words rests, laid out `width` wide, in points; nil for a layout that
    /// answers none.
    /// Design: docs/design/host/layout.md#a-first-baseline
    func firstBaseline(width: Double?) -> Double? {
        nil
    }

    /// Places the children in `bounds`, in points.
    func arrange(in bounds: Rect) {}

    /// What stands over this arrangement's room on each edge, in points - the system's bars, a cutout, the keyboard -
    /// as the arrangement around it passes it down: its own bars take their edge, its page the rest.
    /// Design: docs/design/platforms/android/pages.md#the-safe-area
    var roomInsets = Clearance.none {
        didSet { if roomInsets != oldValue { requestLayout() } }
    }

    /// Whether two lists hold the same views in the same order.
    private static func same(_ left: [AndroidView], _ right: [AndroidView]) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy { $0 === $1 }
    }

    /// A measured extent within what `spec` allows.
    private func resolve(_ spec: Int32, _ natural: Double) -> Int32 {
        switch ViewConstants.mode(spec) {
        case ViewConstants.exactly: ViewConstants.size(spec)
        case ViewConstants.atMost: min(AndroidPixels.size(natural, density: density), ViewConstants.size(spec))
        default: AndroidPixels.size(natural, density: density)
        }
    }
}
