// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What moves an axis of a phase layout's phase under the user's hand. This library's own.
///
///     PhaseLayout(cards, id: \.name, phase: $turn) { … } placements: { room, phase in … }
///         .axis(\.self, input: .scroll(.horizontal), range: 0...6, snaps: .every(1))
///
/// Design: docs/design/views/phase-layout.md#the-hand
public struct LayoutInput: Equatable, Sendable {
    /// Which way the hand moves the phase.
    public enum Axis: Int32, Equatable, Sendable {
        /// Across: the hand moving sideways, the phase growing as it moves to the left.
        case horizontal = 0

        /// Down: the hand moving up and down, the phase growing as it moves up.
        case vertical = 1
    }

    /// How far the hand travels for one unit of the phase.
    public enum Travel: Equatable, Sendable {
        /// So many device units, one at least.
        case points(Double)

        /// As far as the view drawn in front moves for one unit.
        case front

        /// The room's length along the axis: a page.
        case room
    }

    /// What moves the axis: a hand one way, two fingers spreading or two fingers turning.
    /// Design: docs/design/views/phase-layout.md#two-fingers
    enum Gesture: Equatable, Sendable {
        /// A finger or a pointer dragged, a trackpad's two fingers and a wheel along `axis`, so far for a unit,
        /// one snap a hand where it `swipes`.
        case hand(Axis, Travel, swipes: Bool)

        /// Two fingers spreading: the axis multiplied by how far they spread.
        case magnification

        /// Two fingers turning: a unit every so many degrees.
        case rotation(degreesPerUnit: Double)
    }

    /// What moves the phase.
    let gesture: Gesture

    /// How a throw goes on once the hand lets go: how far it carries, and the curve it slows on.
    public let throwing: Motion

    /// The hand over the views: a finger or a pointer dragged, a trackpad's two fingers and a wheel move the axis
    /// with them; let go with speed, the run is thrown on to where the throw would end - the snap nearest it, where
    /// the axis has snaps - as `throwing` says, and let go still it comes onto the nearest under the layout's motion,
    /// a unit a length. Two axes scrolled one across and one down are a pan: the hand moves both, whichever way it
    /// goes.
    ///
    ///     .axis(\.self, input: .scroll(.horizontal), range: 0...6, snaps: .every(1))
    ///     .axis(\.self, input: .scroll(.horizontal, throwing: .spring(response: .milliseconds(500))), …)
    ///     .axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 90), range: 0...3)
    ///
    /// - Parameters:
    ///   - axis: which way it scrolls.
    ///   - pointsPerUnit: how far the hand travels for one unit of the phase, in device units; one at least. Unless
    ///     said, as far as the view drawn in front moves for one unit where the run stands - the hand carries it
    ///     with it, whatever size the room makes it.
    ///   - throwing: how a throw goes on. Eased, its length says how far it carries - the hand's speed for that long,
    ///     over how steeply the curve sets out - and the curve how it slows; a spring carries the hand's speed for
    ///     a third of its response, and settles as springs do. Either sets out at the hand's speed, so a throw never
    ///     speeds up after the lift. A light friction unless said.
    /// - Returns: the input.
    public static func scroll(
        _ axis: Axis, pointsPerUnit: Double? = nil, throwing: Motion = .eased(.milliseconds(400), .cubicOut)
    ) -> LayoutInput {
        LayoutInput(gesture: .hand(axis, travel(pointsPerUnit), swipes: false), throwing: throwing)
    }

    /// One snap a hand: the hand moves the run with it, but one snap at most either way from where it took it,
    /// however far it goes - a trackpad's quick flick included - and let go with speed, the run goes on to the next
    /// snap that way and no farther; a wheel's notch swipes it one snap from where it rests. Cards swiped one by
    /// one; a page at a time. Its axis needs snaps.
    ///
    ///     .axis(\.self, input: .swipe(.horizontal), range: 0...6, snaps: .every(1))
    ///
    /// - Parameters:
    ///   - axis: which way it swipes.
    ///   - pointsPerUnit: how far the hand travels for one unit of the phase, in device units; one at least. Unless
    ///     said, as far as the view drawn in front moves for one unit as the hand takes the run - measured as if the
    ///     run stood on the snap nearest, and kept while the hand holds it.
    ///   - throwing: how the run goes on to the next snap once thrown; a light friction unless said.
    /// - Returns: the input.
    public static func swipe(
        _ axis: Axis, pointsPerUnit: Double? = nil, throwing: Motion = .eased(.milliseconds(400), .cubicOut)
    ) -> LayoutInput {
        LayoutInput(gesture: .hand(axis, travel(pointsPerUnit), swipes: true), throwing: throwing)
    }

    /// A page a hand: a swipe whose hand travels the room's length along `axis` for one unit of the phase, so a
    /// board is a screen however the room turns - the hand moves the run one snap at most, and thrown, on to the
    /// next page and no farther.
    ///
    ///     .axis(\.self, input: .pages(.horizontal), range: 0...3, snaps: .every(1))
    ///
    /// - Parameters:
    ///   - axis: which way the pages turn.
    ///   - throwing: how the run goes on to the next page once thrown; a light friction unless said.
    /// - Returns: the input.
    public static func pages(_ axis: Axis, throwing: Motion = .eased(.milliseconds(400), .cubicOut)) -> LayoutInput {
        LayoutInput(gesture: .hand(axis, .room, swipes: true), throwing: throwing)
    }

    /// Two fingers spreading or pinching - on a touch screen, or a trackpad's pinch: the axis is a magnification,
    /// multiplied by how far the fingers spread, so their distance doubled doubles it and halved halves it. Let go
    /// with speed, it goes on to where it would end - the snap nearest it, where the axis has snaps - with a light
    /// friction; let go still, onto the nearest. Its range stands above nought.
    ///
    ///     .axis(\.zoom, input: .magnification, range: 0.5...2)
    ///     .axis(\.zoom, input: .magnification, range: 0.5...2, snaps: [1])
    ///
    /// Two fingers turning at once may move another axis by `rotation(degreesPerUnit:)`, and the hand - a pan, a
    /// scroll - goes on with their middle.
    public static var magnification: LayoutInput {
        magnification(throwing: .eased(.milliseconds(400), .cubicOut))
    }

    /// The same, thrown on as `throwing` says.
    ///
    ///     .axis(\.zoom, input: .magnification(throwing: .spring(response: .milliseconds(500))), range: 1...4)
    ///
    /// - Parameter throwing: how the axis goes on once let go.
    /// - Returns: the input.
    public static func magnification(throwing: Motion) -> LayoutInput {
        LayoutInput(gesture: .magnification, throwing: throwing)
    }

    /// Two fingers turning - on a touch screen, or a trackpad's rotation: the axis moves a unit for every
    /// `degreesPerUnit` the fingers turn, growing as they turn clockwise. Let go with speed, it goes on to where it
    /// would end - the snap nearest it, where the axis has snaps - as `throwing` says; let go still, onto the
    /// nearest.
    ///
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, circular: true)
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 90), range: 0...4, snaps: .every(1), circular: true)
    ///
    /// - Parameters:
    ///   - degreesPerUnit: how far the fingers turn for one unit of the axis, in degrees; above nought.
    ///   - throwing: how the axis goes on once let go; a light friction unless said.
    /// - Returns: the input.
    public static func rotation(
        degreesPerUnit: Double, throwing: Motion = .eased(.milliseconds(400), .cubicOut)
    ) -> LayoutInput {
        let degrees = degreesPerUnit.isFinite && degreesPerUnit > 0 ? degreesPerUnit : 360
        return LayoutInput(gesture: .rotation(degreesPerUnit: degrees), throwing: throwing)
    }

    /// The travel `pointsPerUnit` says: so many points, one at least, or the view in front's.
    static func travel(_ pointsPerUnit: Double?) -> Travel {
        pointsPerUnit.map { .points(max($0, 1)) } ?? .front
    }
}

extension LayoutInput.Axis: HostRepresentable {}
