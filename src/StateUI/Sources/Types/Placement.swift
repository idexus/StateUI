// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHERE ONE VIEW GOES - the answer a layout of the author's own gives about
// each of its children, and the numbers that answer is packed into for the
// host to write.
//
// The type is the author's: a rectangle and the transform that goes with it.
// The packing below is the boundary's: twelve plain numbers a view, in one
// order, written straight into a buffer the host reads by stride. Both are
// here because they are the SAME fact - what a placement is - said once for
// the author and once for the crossing.

/// Where one view goes and how it is turned. This library's own.
///
/// What a `PlacedLayout`'s arithmetic answers. Every field but the rectangle
/// has a default that means "as it was drawn", so a layout that only positions
/// its views says `Placement(rect)` and nothing else.
///
///     Placement(Rect(x, 0, 120, 170), transform: .turn(40).scale(0.8), zIndex: 2)
///
/// Each of them IS a MAUI property of the view being placed, written onto it -
/// so a view inside a `PlacedLayout` is turned, scaled and faded from HERE
/// rather than in the closure that builds it, which the placement would
/// overwrite.
///
/// EVERY ONE OF THEM MEANS THE SAME PICTURE ON EVERY PLATFORM, and that is
/// what decides the list. A move, a turn in the plane of the screen and a
/// change of size are the same arithmetic wherever they are drawn, about the
/// view's own centre. A turn out of that plane is not: `RotationX` and
/// `RotationY` are projected through a camera each platform chooses for itself
/// - measured on one run of cards at the same angle, Apple turned them away
/// while Android drew them tilted in the plane and moved as well - so they are
/// not here. A card turned away is written as a `scaleX` of `cos(angle)`,
/// which is what such a card looks like and is exact everywhere.
///
/// The ANCHOR is not here either: a turn and a scale are centred on the view,
/// which is what makes them the same everywhere, and moving that centre is
/// worked out from the view's own SIZE - read at the moment the property is
/// written, before this layout has given the view one. It goes on the view
/// instead, in the closure that builds it, where it is a constant.
public struct Placement {
    /// Where the view goes, in device units from the layout's own top left.
    /// MAUI: AbsoluteLayout.LayoutBounds.
    public var bounds: Rect

    /// How it is moved, turned and sized from there, about its own centre.
    public var transform: ViewTransform

    /// How opaque, from 0 to 1 - which is one of the two ways the far cards of
    /// a gallery are sent into the background. MAUI: VisualElement.Opacity.
    public var opacity: Double

    /// How dark, from 0 (as it is drawn) to 1 (gone), and the other way.
    /// This library's own.
    ///
    /// It is the opacity of the SHADE - a view of the author's own, given to
    /// the layout by `.shade(_:)` and drawn over every placed view. A layout
    /// with no shade wears none of this, whatever the arithmetic answers.
    ///
    /// The trap `opacity` walks into and this one does not: a view faded to a
    /// half shows whatever is BEHIND it, which in a run of overlapping cards is
    /// the next card rather than the page. A shade darkens what is there. And
    /// it is a VIEW rather than a colour because only its author knows the
    /// shape it has to match - a card with rounded corners needs a shade with
    /// the same corners.
    public var shade: Double

    /// Which views are drawn over which: a higher number is nearer the reader.
    /// It is the one part of a placement that does not travel, an order having
    /// no half-way. MAUI: VisualElement.ZIndex.
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
    /// The order a run of placements is drawn in, as ranks from the back
    /// forward - which is what the platform is told, in place of the numbers
    /// the arithmetic answered.
    ///
    /// A z-index says WHICH IS DRAWN OVER WHICH and nothing else, so the order
    /// is the whole of its meaning. Arithmetic over a value the reader is
    /// moving answers a NUMBER that changes on every report while the order it
    /// expresses changes only when two views actually swap - and a platform
    /// given a new z-index puts its children in order again, which is a whole
    /// measure of the layout. Measured on a run of fifteen cards: a report
    /// that rewrote every z-index was followed by 3.15 measures of all fifteen
    /// and the next placement 27.2 ms later, against 0.17 and 15.8 ms for one
    /// that left them alone. Ranks change when the picture changes and at no
    /// other time.
    ///
    /// Equal numbers keep the order they were written in, so a run that says
    /// nothing about drawing order is drawn first to last.
    ///
    /// - Parameter placements: the run, in the order the views stand in.
    /// - Returns: each view's rank, in the same order.
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

/// Where one view goes, packed as plain numbers for the host to write.
///
/// TWELVE DOUBLES A VIEW, in the order below. A packed answer rather than a
/// message because this crosses on the platform's own frames: there is no
/// identity to carry, no property to name and nothing to diff - the host holds
/// the controls already and writes what arrives onto the child in that
/// position.
enum PackedPlacement {
    /// How many numbers one view takes.
    static let fields = 12

    /// The shade of a layout that has none, which is what tells the host to
    /// look for no shade view under the placed one.
    ///
    /// A layout WITH a shade answers 0 for a view that wears none of it, and
    /// nought is a shade like any other - so the absence needs a number no
    /// opacity can be. See `PlacedLayout.shade(_:)`.
    static let unshaded = -1.0

    /// Writes one placement into a buffer.
    ///
    /// - Parameters:
    ///   - placement: where the view goes and how it is turned.
    ///   - buffer: where to write.
    ///   - offset: the first number to write.
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
