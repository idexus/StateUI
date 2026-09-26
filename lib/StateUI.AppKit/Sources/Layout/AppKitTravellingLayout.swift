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

    /// Where the children's places animate; nil places them at once.
    weak var layoutMotion: LayoutMotion?

    /// The layout's own motion, as its patches said it; nil while it says nothing of its own.
    var motion: HostLayoutMotion?

    /// Whether this layout's frame, or any frame under it, is read.
    var framesRead = false

    /// Whether a patch reached the layout since its last arrangement.
    private var patched = false

    /// The width of the last arrangement; nil before the first.
    private var arrangedWidth: CGFloat?

    private var arrangement = Arrangement()

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

    /// Notes that a patch reached the layout: its next arrangement places what the patch changed.
    func patchArrived() {
        patched = true
    }

    /// Starts an arrangement, deciding once for every child how it is placed.
    func beginArrangement() {
        let width = bounds.width
        let said = patched && arrangedWidth != nil
        let resized = arrangedWidth.map { abs($0 - width) > 0.5 } ?? false
        patched = false
        arrangedWidth = width

        arrangement = layoutMotion?.arrangement(
            said: said,
            resized: resized,
            motion: motion,
            framesRead: framesRead) ?? Arrangement()
    }

    /// Stands `item` at `frame`, or on its way there; an item no element places arrives at once.
    func place(_ item: AppKitLayoutItem, at frame: NSRect) {
        guard let layoutMotion, let placed = item.placed else {
            item.view.frame = frame
            return
        }

        var stated: MotionLanes = []
        if item.values.width != nil { stated.insert(.width) }
        if item.values.height != nil { stated.insert(.height) }
        layoutMotion.place(
            placed,
            mount: item.mount,
            at: frame.placed,
            stated: stated,
            fadeIn: item.fadeIn,
            in: arrangement)
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
