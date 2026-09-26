// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children animate to the places a patch gives them.
/// It begins each arrangement with `beginArrangement(width:)` and hands every child's place to `place(_:at:)`.
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class AndroidTravellingLayout: AndroidLayoutView {
    /// Where the children's places animate; nil places them at once.
    weak var layoutMotion: LayoutMotion?

    /// The layout's own motion, as its patches said it; nil while it says nothing of its own.
    var motion: HostLayoutMotion?

    /// Whether this layout's frame, or any frame under it, is read.
    var framesRead = false

    /// Whether a patch reached the layout since its last arrangement.
    private var patched = false

    /// The width of the last arrangement, in points; nil before the first.
    private var arrangedWidth: Double?

    private var arrangement = Arrangement()

    /// Notes that a patch reached the layout: its next arrangement places what the patch changed.
    func patchArrived() {
        patched = true
    }

    /// Starts an arrangement `width` points wide, deciding once for every child how it is placed.
    func beginArrangement(width: Double) {
        let said = patched && arrangedWidth != nil
        let resized = arrangedWidth.map { abs($0 - width) > 0.5 } ?? false
        patched = false
        arrangedWidth = width

        arrangement = layoutMotion?.arrangement(
            said: said, resized: resized, motion: motion, framesRead: framesRead) ?? Arrangement()
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: AndroidLayoutItem, at place: Rect) {
        guard let layoutMotion else {
            item.view.layout(place)
            return
        }

        var stated: MotionLanes = []
        if item.values.width != nil { stated.insert(.width) }
        if item.values.height != nil { stated.insert(.height) }
        layoutMotion.place(
            item.view, mount: item.mount, at: place, stated: stated, fadeIn: item.fadeIn, in: arrangement)
    }
}
