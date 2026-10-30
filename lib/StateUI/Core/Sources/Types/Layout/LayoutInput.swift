// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What moves an axis of a motion layout's parameters under the user's hand. This library's own.
///
///     MotionLayout(cards, id: \.name, parameters: $turn) { … } placements: { room, parameters in … }
///         .axis(\.self, input: .scroll(.horizontal), range: 0...6, snaps: .every(1))
///
/// Design: docs/design/views/motion-layout.md#the-hand
public struct LayoutInput: Equatable, Sendable {
    /// Which way the hand moves the parameters.
    public enum Orientation: Int32, Equatable, Sendable {
        /// Across: the hand moving sideways, the parameters growing as it moves to the left.
        case horizontal = 0

        /// Down: the hand moving up and down, the parameters growing as it moves up.
        case vertical = 1
    }

    /// How far the hand travels for one unit of the parameters.
    public enum Travel: Equatable, Sendable {
        /// So many device units, one at least.
        case points(Double)

        /// As far as the view drawn in front moves for one unit.
        case front

        /// The room's length along the axis: a page.
        case room
    }

    /// What moves the axis: a hand one way, two fingers spreading or two fingers turning.
    /// Design: docs/design/views/motion-layout.md#two-fingers
    enum Gesture: Equatable, Sendable {
        /// A finger or a pointer dragged, a trackpad's two fingers and a wheel along `axis`, so far for a unit,
        /// one snap a hand where it `swipes`.
        case hand(Orientation, Travel, swipes: Bool)

        /// Two fingers spreading: the axis multiplied by how far they spread.
        case magnification

        /// Two fingers turning: a unit every so many degrees.
        case rotation(degreesPerUnit: Double)
    }

    /// What moves the parameters.
    let gesture: Gesture

    /// The hand over the views: a finger or a pointer dragged, a trackpad's two fingers and a wheel move the axis with
    /// them; let go with speed, the run is thrown on to where the throw would end - the snap nearest it, where the axis
    /// has snaps - as the layout's `throwMotion(_:)` says, and let go still it comes onto the nearest under the
    /// layout's motion, a unit a length. Two axes scrolled one across and one down are a pan: the hand moves both,
    /// whichever way it goes.
    ///
    ///     .axis(\.self, input: .scroll(.horizontal), range: 0...6, snaps: .every(1))
    ///     .axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 90), range: 0...3)
    ///
    /// - Parameters:
    ///   - orientation: which way it scrolls, horizontally or vertically.
    ///   - pointsPerUnit: how far the hand travels for one unit of the parameters, in device units; one at least.
    ///     Unless said, as far as the view drawn in front moves for one unit where the run stands - the hand carries it
    ///     with it, whatever size the room makes it.
    /// - Returns: the input.
    public static func scroll(_ orientation: Orientation, pointsPerUnit: Double? = nil) -> LayoutInput {
        LayoutInput(gesture: .hand(orientation, travel(pointsPerUnit), swipes: false))
    }

    /// One snap a hand: the hand moves the run with it, but one snap at most either way from where it took it,
    /// however far it goes - a trackpad's quick flick included - and let go with speed, the run goes on to the next
    /// snap that way and no farther; a wheel's notch swipes it one snap from where it rests. Cards swiped one by
    /// one; a page at a time. Its axis needs snaps.
    ///
    ///     .axis(\.self, input: .swipe(.horizontal), range: 0...6, snaps: .every(1))
    ///
    /// - Parameters:
    ///   - orientation: which way it swipes, horizontally or vertically.
    ///   - pointsPerUnit: how far the hand travels for one unit of the parameters, in device units; one at least.
    ///     Unless said, as far as the view drawn in front moves for one unit as the hand takes the run - measured as if the
    ///     run stood on the snap nearest, and kept while the hand holds it.
    /// - Returns: the input.
    public static func swipe(_ orientation: Orientation, pointsPerUnit: Double? = nil) -> LayoutInput {
        LayoutInput(gesture: .hand(orientation, travel(pointsPerUnit), swipes: true))
    }

    /// A page a hand: a swipe whose hand travels the room's length in `orientation` for one unit of the parameters, so
    /// a board is a screen however the room turns - the hand moves the run one snap at most, and thrown, on to the next
    /// page and no farther.
    ///
    ///     .axis(\.self, input: .pages(.horizontal), range: 0...3, snaps: .every(1))
    ///
    /// - Parameters:
    /// - Parameter orientation: which way the pages turn, horizontally or vertically.
    /// - Returns: the input.
    public static func pages(_ orientation: Orientation) -> LayoutInput {
        LayoutInput(gesture: .hand(orientation, .room, swipes: true))
    }

    /// Two fingers spreading or pinching - on a touch screen, or a trackpad's pinch: the axis is a magnification,
    /// multiplied by how far the fingers spread, so their distance doubled doubles it and halved halves it. Let go
    /// with speed, it goes on to where it would end - the snap nearest it, where the axis has snaps - as the layout's
    /// `throwMotion(_:)` says; let go still, onto the nearest. Its range stands above nought.
    ///
    ///     .axis(\.zoom, input: .magnification, range: 0.5...2)
    ///     .axis(\.zoom, input: .magnification, range: 0.5...2, snaps: [1])
    ///
    /// Two fingers turning at once may move another axis by `rotation(degreesPerUnit:)`, and the hand - a pan, a
    /// scroll - goes on with their middle.
    public static var magnification: LayoutInput {
        LayoutInput(gesture: .magnification)
    }

    /// Two fingers turning - on a touch screen, or a trackpad's rotation: the axis moves a unit for every
    /// `degreesPerUnit` the fingers turn, growing as they turn clockwise. Let go with speed, it goes on to where it
    /// would end - the snap nearest it, where the axis has snaps - as the layout's `throwMotion(_:)` says; let go
    /// still, onto the nearest.
    ///
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, periodic: true)
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 90), range: 0...4, snaps: .every(1), periodic: true)
    ///
    /// - Parameter degreesPerUnit: how far the fingers turn for one unit of the axis, in degrees; above nought.
    /// - Returns: the input.
    public static func rotation(degreesPerUnit: Double) -> LayoutInput {
        let degrees = degreesPerUnit.isFinite && degreesPerUnit > 0 ? degreesPerUnit : 360
        return LayoutInput(gesture: .rotation(degreesPerUnit: degrees))
    }

    /// The travel `pointsPerUnit` says: so many points, one at least, or the view in front's.
    static func travel(_ pointsPerUnit: Double?) -> Travel {
        pointsPerUnit.map { .points(max($0, 1)) } ?? .front
    }
}

extension LayoutInput.Orientation: HostRepresentable {}
