// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A StateUI layout: its children's views placed by the host layer's arithmetic, each on its way to its place where
/// the layout moves (`TravelingPlaces`), its measurements kept until something in it changes.
@MainActor
class UIKitLayoutView: UIView, UIKitSteppable {
    /// What a reader's step performs, while the element says it is adjustable.
    var stepAction: ((AccessibilityAdjustment) -> Void)?

    override func accessibilityIncrement() { stepAction?(.increment) }

    override func accessibilityDecrement() { stepAction?(.decrement) }

    let measurements = MeasurementCache()

    /// How the children travel to their places, by the host layer's rule.
    let places = TravelingPlaces()

    private(set) var items: [UIKitLayoutItem] = []

    /// What the layout says once it has placed its children: whoever reads a frame may have moved.
    var laidOut: (() -> Void)?

    /// The direction the children are laid out in.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { setNeedsLayout() } }
    }

    /// What the layout paints of its own box, and whether it cuts what it shows to the box's outline.
    let box = UIKitBox()

    /// Whether a touch beside every child goes on to what stands under the layout.
    var passesBeside = false

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitLayoutView is made in code")
    }

    /// The children, in the tree's order: views that left are taken out, new ones put in.
    func setItems(_ items: [UIKitLayoutItem]) {
        guard items.count != self.items.count || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        else { return }

        let hosts = [self, box.backdropView?.contentView]
        for gone in self.items
        where hosts.contains(where: { $0 === gone.view.superview }) && !items.contains(where: { $0.view === gone.view }) {
            gone.view.removeFromSuperview()
        }
        self.items = items
        standChildren()
        forgetMeasurements()
        setNeedsLayout()
    }

    /// Where the children stand: in the box's interactive glass, so a touch on them is the glass's as well - else in
    /// the layout, above its backdrop.
    /// Design: docs/design/platforms/uikit/drawing.md#interactive-glass
    var childrenHost: UIView {
        box.backdropView.flatMap { $0.holdsChildren ? $0.contentView : nil } ?? self
    }

    /// Stands each child in the children's host in the tree's order - the backdrop beneath them in the layout - then
    /// in the order the layout draws them (`orderChildren`).
    private func standChildren() {
        let host = childrenHost
        let first = host === self && box.backdropView != nil ? 1 : 0
        for (index, item) in items.enumerated()
        where item.view.superview !== host || host.subviews.firstIndex(of: item.view) != first + index {
            host.insertSubview(item.view, at: first + index)
        }
        orderChildren()
    }

    /// Stands the children again where their host changed - the box's interactive glass came or went - their order
    /// otherwise left as it is.
    private func followChildrenHost() {
        let host = childrenHost
        guard items.contains(where: { $0.view.superview !== host }) else { return }
        standChildren()
    }

    /// Orders the children back to front as the layout draws them; most draw them in the tree's order.
    func orderChildren() {}

    func forgetMeasurements() {
        measurements.invalidate()
    }

    /// The size the children ask for, offered `width`.
    func measuredSize(width: Double?) -> LayoutSize {
        measurements.size(offering: width) { contentSize(width: width) }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let measured = measuredSize(width: size.width.isFinite ? size.width : nil)
        return CGSize(width: measured.width, height: measured.height)
    }

    /// What this layout's arithmetic asks for, offered `width`.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// How far below its top its first line of words rests, laid out `width` wide; nil for a layout that answers none.
    /// Design: docs/design/host/layout.md#a-first-baseline
    func firstBaseline(width: Double?) -> Double? {
        nil
    }

    /// Stands every child in `bounds`, by this layout's arithmetic.
    func arrange(in bounds: Rect) {}

    /// The size the layout is bound for while its place travels: its children stand there meanwhile, as they will
    /// once it lands, its own box traveling around them. Design: docs/design/host/motion.md#a-layout-bound-for-a-size
    var arrangementRoom: CGSize? {
        didSet { if arrangementRoom != oldValue { setNeedsLayout() } }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        box.paint(on: self)
        followChildrenHost()
        let room = arrangementRoom ?? bounds.size
        places.begin(width: room.width)
        arrange(in: Rect(x: 0, y: 0, width: room.width, height: room.height))
        laidOut?()
    }

    /// The box's background, its outline's stroke, its shape, and whether it cuts what the layout shows to that
    /// shape.
    func setBox(background: HostValue?, stroke: HostValue?, width: Double?, shape: HostValue?, clips: Bool) {
        box.set(background: background, stroke: stroke, width: width, shape: shape, clips: clips)
        box.paint(on: self)
        followChildrenHost()
    }

    /// A touch outside the shape the layout cuts to reaches nothing of it: UIKit tests a touch against the bounds.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event) && box.takes(point, in: bounds)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        let beside = hit === self || hit === box.backdropView || hit === box.backdropView?.contentView
        return passesBeside && beside ? nil : hit
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: UIKitLayoutItem, at place: Rect) {
        guard let placed = item.placed else {
            item.view.frame = CGRect(x: place.x, y: place.y, width: place.width, height: place.height)
            return
        }
        places.place(
            placed, mount: item.mount, at: place, values: item.values, natural: { item.size(offered: nil) },
            fadeIn: item.fadeIn)
    }
}
#endif
