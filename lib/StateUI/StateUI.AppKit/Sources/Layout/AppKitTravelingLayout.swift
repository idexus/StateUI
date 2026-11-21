// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children animate to the places a patch gives them.
/// It begins each arrangement with `beginArrangement()` and hands every child's place to `place(_:at:)`.
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class AppKitTravelingLayout: AppKitHitTestView, AppKitDirectedLayout {
    /// The direction the children are laid out in; a turn lays them out again.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { needsLayout = true } }
    }

    /// The layout's own box: its background and outline on its shape, and its cut.
    let decoration = AppKitDecoration()

    /// How the children travel to their places, by the host layer's rule.
    let places = TravelingPlaces()

    /// The views it presents, in the tree's order - its items' and those kept as they leave - as they last came.
    var presented: [NSView] = []

    /// Draws the children again as the layout draws them; a layout of no order of its own keeps the tree's.
    func orderChildren() {}

    /// Stands the subviews as the layout draws them: the tree's order, a run's ranks where `placements` say them, a
    /// child a shared entry carries last - a view kept as it leaves over them all where they move.
    /// Design: docs/design/host/layout.md#drawing-order
    func standInDrawingOrder(of items: [AppKitLayoutItem], placedBy placements: [HostPlacement]) {
        let ordered = places.drawingOrder(of: items.map(\.mount), placedBy: placements)
        guard !placements.isEmpty || ordered != Array(items.indices) else { return replaceSubviews(with: presented) }

        let leaving = presented.filter { view in !items.contains { $0.view === view } }
        replaceSubviews(with: ordered.map { items[$0].view } + leaving)
    }

    override func layout() {
        super.layout()
        decoration.clip(self)
    }

    /// A plain box is its layer's color, with no backing store; only a drawn one draws.
    override var wantsUpdateLayer: Bool { !decoration.draws }

    override func updateLayer() {
        layer?.backgroundColor = decoration.layerColor
    }

    /// The whole of the view under a transform, which AppKit leaves out of what it takes for visible.
    override var visibleRect: NSRect { drawnRect(visible: super.visibleRect) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        decoration.draw(in: bounds)
    }

    /// The size the layout is bound for while its place travels: its children stand there meanwhile, as they will
    /// once it lands, its own box traveling around them. Design: docs/design/host/motion.md#a-layout-bound-for-a-size
    var arrangementRoom: NSSize? {
        didSet { if arrangementRoom != oldValue { needsLayout = true } }
    }

    /// Where the children are arranged: the room the layout is bound for, else its bounds.
    var arrangementBounds: NSRect {
        arrangementRoom.map { NSRect(origin: .zero, size: $0) } ?? bounds
    }

    /// Starts an arrangement, deciding once for every child how it is placed.
    func beginArrangement() {
        places.begin(width: Double(arrangementBounds.width), height: Double(arrangementBounds.height))
    }

    /// Stands `item` at `frame`, or on its way there; an item no element places arrives at once.
    func place(_ item: AppKitLayoutItem, at frame: NSRect) {
        guard let placed = item.placed else {
            item.view.frame = frame
            return
        }
        places.place(
            placed, mount: item.mount, at: frame.placed, values: item.values,
            natural: { item.size(offered: nil) }, enter: item.enter)
    }
}

extension NSRect {
    /// This rectangle as StateUI's `Rect`.
    var placed: Rect { Rect(x: minX, y: minY, width: width, height: height) }

    /// StateUI's `Rect` as a native rectangle.
    init(placed rect: Rect) {
        self.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}

/// A layout that lays its children out left to right, or right to left turned about its middle.
/// Design: docs/design/host/layout.md#right-to-left
@MainActor
protocol AppKitDirectedLayout: NSView {
    /// The direction the children are laid out in, the element's.
    var direction: LayoutDirection { get set }
}

#endif
