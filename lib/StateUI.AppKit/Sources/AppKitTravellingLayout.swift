// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A layout whose children animate to the places a patch gives them.
/// It begins each arrangement with `beginArrangement()` and hands every child's place to `place(_:at:)`.
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class AppKitTravellingLayout: AppKitHitTestView {
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
        if item.width != nil { stated.insert(.width) }
        if item.height != nil { stated.insert(.height) }
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
#endif
