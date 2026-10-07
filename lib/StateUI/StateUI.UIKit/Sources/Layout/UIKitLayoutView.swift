// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A StateUI layout: its children's views placed by the host layer's arithmetic, each on its way to its place where
/// the layout moves (`TravellingPlaces`), its measurements kept until something in it changes.
@MainActor
class UIKitLayoutView: UIView {
    let measurements = MeasurementCache()

    /// How the children travel to their places, by the host layer's rule.
    let places = TravellingPlaces()

    private(set) var items: [UIKitLayoutItem] = []

    /// What the layout says once it has placed its children: whoever reads a frame may have moved.
    var laidOut: (() -> Void)?

    /// The direction the children are laid out in.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { setNeedsLayout() } }
    }

    /// What the layout paints of its own box, and whether it cuts what it shows to the box's outline.
    private(set) var box = UIKitBox()

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

        for gone in self.items where gone.view.superview === self && !items.contains(where: { $0.view === gone.view }) {
            gone.view.removeFromSuperview()
        }
        // The backdrop stands beneath the children.
        let first = box.backdropView == nil ? 0 : 1
        for (index, item) in items.enumerated()
        where item.view.superview !== self || subviews.firstIndex(of: item.view) != first + index {
            insertSubview(item.view, at: first + index)
        }
        self.items = items
        forgetMeasurements()
        setNeedsLayout()
    }

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

    /// Stands every child in `bounds`, by this layout's arithmetic.
    func arrange(in bounds: Rect) {}

    override func layoutSubviews() {
        super.layoutSubviews()
        box.paint(on: self)
        places.begin(width: bounds.width)
        arrange(in: Rect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        laidOut?()
    }

    /// The box's background, its outline's stroke, its shape, and whether it cuts what the layout shows to that
    /// shape.
    func setBox(background: HostValue?, stroke: HostValue?, width: Double?, shape: HostValue?, clips: Bool) {
        box.set(background: background, stroke: stroke, width: width, shape: shape, clips: clips)
        box.paint(on: self)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return passesBeside && hit === self ? nil : hit
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: UIKitLayoutItem, at place: Rect) {
        guard let placed = item.placed else {
            item.view.frame = CGRect(x: place.x, y: place.y, width: place.width, height: place.height)
            return
        }
        places.place(placed, mount: item.mount, at: place, values: item.values, fadeIn: item.fadeIn)
    }
}
#endif
