// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where one view of a placed layout goes, said once for the author as a
// `Placement` and once for the host as twelve numbers.
// Design: docs/design/types/placement.md#where-one-view-goes

/// Where one view goes and how it is turned: what a `PlacedLayout`'s
/// arithmetic answers for each of its views.
///
///     Placement(Rect(x, 0, 120, 170), transform: .turn(40).scale(0.8), zIndex: 2)
///
/// Every field but the bounds defaults to the view as it was drawn, so a
/// layout that only positions its views says `Placement(rect)`. The fields are
/// written onto the placed view: turn, scale and fade it here rather than in
/// the closure that builds it, which the placement would overwrite. A turn out
/// of the screen's plane is `.turn(_:)`, drawn flat, and a pivot is set in
/// that closure.
///
/// Design: docs/design/types/placement.md#one-picture-on-every-platform
public struct Placement: StateValue {
    /// Where the view goes, in device units from the layout's own top left.
    public var bounds: Rect

    /// How it is moved, turned and sized from there, about its own centre.
    public var transform: ViewTransform

    /// How opaque, from 0 to 1.
    public var opacity: Double

    /// How far the layout's shade covers the view, from 0 to 1: the opacity of
    /// the view given by `.shade(_:)`, drawn over this one. Nothing without a
    /// shade.
    ///
    /// Unlike `opacity`, a shade darkens the view rather than showing what is
    /// behind it - in a run of overlapping cards, the next card.
    ///
    /// Design: docs/design/types/placement.md#shade-and-opacity
    public var shade: Double

    /// Which views are drawn over which: a higher number is nearer the user.
    /// It changes at once, without animation.
    public var zIndex: Int

    /// A placement, and how the view is turned in it.
    ///
    ///     Placement(
    ///         Rect(x, 0, 176, 248),
    ///         transform: .turn(-40).scale(0.86),
    ///         opacity: 0.7,
    ///         zIndex: 2)
    ///
    /// A layout that only puts its views somewhere gives the bounds alone.
    ///
    /// - Parameters:
    ///   - bounds: where the view goes, in device units from the layout's own
    ///     top left.
    ///   - transform: how it is moved, turned and sized from there, about its
    ///     own centre. As it was drawn, unless it says otherwise.
    ///   - opacity: how opaque, from 0 to 1.
    ///   - shade: how dark, from 0 to 1 - the opacity of the view the layout
    ///     was given by `.shade(_:)`. Nothing at all without one.
    ///   - zIndex: which views are drawn over which.
    public init(
        _ bounds: Rect,
        transform: ViewTransform = .identity,
        opacity: Double = 1,
        shade: Double = 0,
        zIndex: Int = 0
    ) {
        self.bounds = bounds
        self.transform = transform
        self.opacity = opacity
        self.shade = shade
        self.zIndex = zIndex
    }
}

extension Placement {
    /// Each view's drawing rank, back to front, in the views' order; equal
    /// numbers keep the order the views stand in.
    /// Design: docs/design/types/placement.md#drawing-order-as-ranks
    static func drawingOrder(of placements: [Placement]) -> [Int] {
        let sorted = placements.indices.sorted {
            placements[$0].zIndex == placements[$1].zIndex
                ? $0 < $1
                : placements[$0].zIndex < placements[$1].zIndex
        }

        var ranks = [Int](repeating: 0, count: placements.count)

        for (rank, index) in sorted.enumerated() { ranks[index] = rank }

        return ranks
    }
}

extension Placement {
    /// The twelve numbers a placement is, in the order `PackedPlacement`
    /// writes them.
    public var carried: StateCarried {
        .lanes([
            bounds.x,
            bounds.y,
            bounds.width,
            bounds.height,
            transform.x,
            transform.y,
            transform.rotation,
            transform.width,
            transform.height,
            opacity,
            Double(zIndex),
            shade,
        ])
    }

    /// A placement back from its twelve numbers. A transform's move, turn and
    /// sizes come back; a shear does not.
    ///
    /// Design: docs/design/types/transforms.md#reading-the-five-properties-back
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == Placement.lanes else {
            return nil
        }

        self.init(
            Rect(lanes[0], lanes[1], lanes[2], lanes[3]),
            transform: ViewTransform(
                x: lanes[4],
                y: lanes[5],
                rotation: lanes[6],
                width: lanes[7],
                height: lanes[8]),
            opacity: lanes[9],
            shade: lanes[11],
            zIndex: Int(lanes[10].rounded()))
    }

    /// Twelve, which is what the host reads by stride.
    public static var lanes: Int { PackedPlacement.fields }
}

/// Where one view goes, as twelve doubles in the order below, written into a
/// buffer the host reads by stride on the platform's own frames.
/// Design: docs/design/types/placement.md#twelve-numbers-a-view
enum PackedPlacement {
    /// How many numbers one view takes.
    static let fields = 12

    /// The shade of a layout with none: a number no opacity can be, which tells
    /// the host to look for no shade view.
    static let unshaded = -1.0

    /// Writes one placement into `buffer`, from `offset`.
    static func write(
        _ placement: Placement,
        into buffer: UnsafeMutablePointer<Double>,
        at offset: Int
    ) {
        let transform = placement.transform

        buffer[offset + 0] = placement.bounds.x
        buffer[offset + 1] = placement.bounds.y
        buffer[offset + 2] = placement.bounds.width
        buffer[offset + 3] = placement.bounds.height
        buffer[offset + 4] = transform.x
        buffer[offset + 5] = transform.y
        buffer[offset + 6] = transform.rotation
        buffer[offset + 7] = transform.width
        buffer[offset + 8] = transform.height
        buffer[offset + 9] = placement.opacity
        buffer[offset + 10] = Double(placement.zIndex)
        buffer[offset + 11] = placement.shade
    }
}
