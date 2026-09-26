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
class AppKitTravellingLayout: AppKitHitTestView, AppKitDirectedLayout {
    /// The direction the children are laid out in; a turn lays them out again.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { needsLayout = true } }
    }

    /// The layout's own box: its background and outline on its shape, and its cut.
    let decoration = AppKitDecoration()

    /// How the children travel to their places, by the host layer's rule.
    let places = TravellingPlaces()

    override func layout() {
        super.layout()
        decoration.clip(self)
    }

    /// A plain box is its layer's colour, with no backing store; only a drawn one draws.
    override var wantsUpdateLayer: Bool { !decoration.draws }

    override func updateLayer() {
        layer?.backgroundColor = decoration.layerColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        decoration.draw(in: bounds)
    }

    /// Starts an arrangement, deciding once for every child how it is placed.
    func beginArrangement() {
        places.begin(width: Double(bounds.width))
    }

    /// Stands `item` at `frame`, or on its way there; an item no element places arrives at once.
    func place(_ item: AppKitLayoutItem, at frame: NSRect) {
        guard let placed = item.placed else {
            item.view.frame = frame
            return
        }
        places.place(placed, mount: item.mount, at: frame.placed, values: item.values, fadeIn: item.fadeIn)
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
