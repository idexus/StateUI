// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One layout's children traveling to their places, the same on every host: as an arrangement begins, it decides
/// once for every child whether the places a patch or a new width gave them animate, and each child then stands at
/// its place or on its way there.
/// Design: docs/design/host/motion.md#layout-motion
@_spi(Host) @MainActor public final class TravelingPlaces {
    /// Where the children's places animate; nil places them at once.
    public weak var layoutMotion: LayoutMotion?

    /// The layout's own motion, as its patches said it; nil while it says nothing of its own.
    public var motion: HostLayoutMotion?

    /// Whether a patch reached the layout since its last arrangement.
    private(set) var patched = false

    /// The width of the last arrangement; nil before the first.
    private var arrangedWidth: Double?

    /// Whether this arrangement places what a patch said, and whether the layout's own width is another.
    private var said = false
    private var resized = false

    private var arrangement = Arrangement()

    /// A layout not arranged yet.
    public init() {}

    /// Notes that a patch reached the layout: its next arrangement places what the patch changed.
    public func patchArrived() {
        patched = true
    }

    /// The room the arrangement under way lays out in.
    private var room = LayoutSize(width: 0, height: 0)

    /// Starts an arrangement in a room `width` by `height`, deciding once for every child how it is placed: what a
    /// patch said travels, what a new width gave arrives.
    public func begin(width: Double, height: Double) {
        room = LayoutSize(width: width, height: height)
        said = patched && arrangedWidth != nil
        resized = arrangedWidth.map { abs($0 - width) > 0.5 } ?? false
        patched = false
        arrangedWidth = width

        arrangement = layoutMotion?.arrangement(
            said: said, resized: resized, motion: motion) ?? Arrangement()
    }

    /// Stands `view`, the mounted element `mount`'s, at `place`, or on its way there; its `values` say which sides
    /// it sizes itself and whether it lays out words, `natural` measures it with no width offered - read for words
    /// as its place sets out - and `enter` brings it in as it is given its first place.
    public func place(
        _ view: any PlacedView, mount: UInt64, at place: Rect, values: LayoutValues,
        natural: () -> LayoutSize, enter: ((LayoutEntry) -> Void)?
    ) {
        guard let layoutMotion else {
            view.placedFrame = place
            return
        }

        var stated: MotionLanes = []
        if values.width != nil { stated.insert(.width) }
        if values.height != nil { stated.insert(.height) }
        // A child that is a body - its own, or its layout's for every child - comes onto its place as its body says.
        let arrangement = values.body.map {
            layoutMotion.arrangement(of: $0, said: said, resized: resized, among: arrangement)
        } ?? arrangement
        layoutMotion.place(
            view, mount: mount, at: place, stated: stated, words: values.words, natural: natural,
            enter: enter, in: arrangement, room: room)
    }

    /// The children of `mounts` back to front as the layout draws them, run by `placements` (`DrawingOrder`).
    public func drawingOrder(of mounts: [UInt64], placedBy placements: [HostPlacement]) -> [Int] {
        DrawingOrder.of(mounts.count, placedBy: placements) { layoutMotion?.drawsInFront(mounts[$0]) == true }
    }
}
