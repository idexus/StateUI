// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How far a child stands from where its layout puts it, lane by lane: what a change of the layout leaves, laid
/// over the child's place - a body's lanes (`LayoutBodies`).
/// Design: docs/design/host/layout.md#bodies
struct LayoutShift: Equatable, Sendable {
    /// The numbers, lane by lane: the bounds' place and size; the transform's five drawn numbers apart - its move
    /// across and down, its turn in degrees, its width and height; the opacity; the shade.
    var lanes: [Double]

    /// Where each part stands among the lanes.
    static let x = 0, y = 1, width = 2, height = 3
    static let moveX = 4, moveY = 5, turn = 6, scaleX = 7, scaleY = 8
    static let opacity = 9, shade = 10

    /// How many lanes a shift has.
    static let count = 11

    /// No shift: the child where its layout puts it.
    static let none = LayoutShift(lanes: Array(repeating: 0, count: count))

    init(lanes: [Double]) {
        self.lanes = lanes
    }

    /// The shift that shows `place` where `shown` stood: the bounds, the opacity and the transform's five drawn
    /// numbers apart - the turn the short way, as a view's own transform travels - and the shade only where both
    /// draw one.
    init(from shown: HostPlacement, to place: HostPlacement) {
        var lanes = LayoutShift.none.lanes
        lanes[Self.x] = shown.bounds.x - place.bounds.x
        lanes[Self.y] = shown.bounds.y - place.bounds.y
        lanes[Self.width] = shown.bounds.width - place.bounds.width
        lanes[Self.height] = shown.bounds.height - place.bounds.height

        let turn = shown.rotation - place.rotation
        lanes[Self.moveX] = shown.translationX - place.translationX
        lanes[Self.moveY] = shown.translationY - place.translationY
        lanes[Self.turn] = turn - (turn / 360).rounded() * 360
        lanes[Self.scaleX] = shown.scaleX - place.scaleX
        lanes[Self.scaleY] = shown.scaleY - place.scaleY

        lanes[Self.opacity] = shown.opacity - place.opacity
        if shown.shade != HostPlacement.unshaded, place.shade != HostPlacement.unshaded {
            lanes[Self.shade] = shown.shade - place.shade
        }
        self.lanes = lanes
    }

    /// A child joining: where its layout puts it, with nothing of it shown yet.
    static func joining(_ place: HostPlacement) -> LayoutShift {
        var joining = LayoutShift.none
        joining.lanes[opacity] = -place.opacity
        return joining
    }

    /// `place` shifted: its bounds, opacity and the transform's five drawn numbers moved by the lanes, its order
    /// its own.
    func applied(to place: HostPlacement) -> HostPlacement {
        guard self != .none else { return place }

        return HostPlacement(
            bounds: Rect(
                x: place.bounds.x + lanes[Self.x], y: place.bounds.y + lanes[Self.y],
                width: place.bounds.width + lanes[Self.width], height: place.bounds.height + lanes[Self.height]),
            translationX: place.translationX + lanes[Self.moveX], translationY: place.translationY + lanes[Self.moveY],
            rotation: place.rotation + lanes[Self.turn], scaleX: place.scaleX + lanes[Self.scaleX],
            scaleY: place.scaleY + lanes[Self.scaleY],
            opacity: min(max(place.opacity + lanes[Self.opacity], 0), 1), zIndex: place.zIndex,
            shade: place.shade == HostPlacement.unshaded
                ? place.shade : min(max(place.shade + lanes[Self.shade], 0), 1))
    }
}
