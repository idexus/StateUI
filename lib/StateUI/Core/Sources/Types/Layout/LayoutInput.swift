// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What moves a layout engine's phase under the user's hand. This library's own.
///
///     LayoutEngine(cards, id: \.name) { … } placements: { room, phase in … }
///         .phase($turn)
///         .input(.scroll(.horizontal))
///
/// Design: docs/design/views/layout-engine.md#the-hand
public struct LayoutInput: Equatable, Sendable {
    /// Which way the hand moves the phase.
    public enum Axis: Int32, Equatable, Sendable {
        /// Across: the hand moving sideways, the phase growing as it moves to the left.
        case horizontal = 0

        /// Down: the hand moving up and down, the phase growing as it moves up.
        case vertical = 1
    }

    /// Which way the hand moves the phase.
    public let axis: Axis

    /// How far the hand travels for one unit of the phase.
    public enum Travel: Equatable, Sendable {
        /// So many device units, one at least.
        case points(Double)

        /// As far as the view drawn in front moves for one unit.
        case front

        /// The room's length along the axis: a page.
        case room
    }

    /// How far the hand travels for one unit of the phase.
    public let travel: Travel

    /// How a throw goes on once the hand lets go: how far it carries, and the curve it slows on.
    public let throwing: Motion

    /// Whether one hand moves the run one snap target at most, either way from where it took it: a swipe's.
    public let swipes: Bool

    /// The hand over the views: a finger or a pointer dragged, a trackpad's two fingers and a wheel move the phase
    /// with them; let go with speed, the run is thrown on to the snap target nearest where the throw would end, as
    /// `throwing` says, and let go still it comes onto the nearest under the layout's motion, a unit a length.
    ///
    ///     .input(.scroll(.horizontal))
    ///     .input(.scroll(.horizontal, throwing: .spring(response: .milliseconds(500), damping: 0.7)))
    ///     .input(.scroll(.horizontal, pointsPerUnit: 90, throwing: .eased(.milliseconds(400), .sineOut)))
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
        LayoutInput(axis: axis, travel: travel(pointsPerUnit), throwing: throwing, swipes: false)
    }

    /// One snap target a hand: the hand moves the run with it, but one target at most either way from where it took
    /// it, however far it goes - a trackpad's quick flick included - and let go with speed, the run goes on to the
    /// next target that way and no farther; a wheel's notch swipes it one target from where it rests. Cards swiped
    /// one by one; a page at a time.
    ///
    ///     .input(.swipe(.horizontal))
    ///
    /// - Parameters:
    ///   - axis: which way it swipes.
    ///   - pointsPerUnit: how far the hand travels for one unit of the phase, in device units; one at least. Unless
    ///     said, as far as the view drawn in front moves for one unit as the hand takes the run - measured as if the
    ///     run stood on the target nearest, and kept while the hand holds it.
    ///   - throwing: how the run goes on to the next target once thrown; a light friction unless said.
    /// - Returns: the input.
    public static func swipe(
        _ axis: Axis, pointsPerUnit: Double? = nil, throwing: Motion = .eased(.milliseconds(400), .cubicOut)
    ) -> LayoutInput {
        LayoutInput(axis: axis, travel: travel(pointsPerUnit), throwing: throwing, swipes: true)
    }

    /// A page a hand: a swipe whose hand travels the room's length along `axis` for one unit of the phase, so a
    /// board is a screen however the room turns - the hand moves the run one snap target at most, and thrown, on to
    /// the next page and no farther.
    ///
    ///     .input(.pages(.horizontal))
    ///
    /// - Parameters:
    ///   - axis: which way the pages turn.
    ///   - throwing: how the run goes on to the next page once thrown; a light friction unless said.
    /// - Returns: the input.
    public static func pages(_ axis: Axis, throwing: Motion = .eased(.milliseconds(400), .cubicOut)) -> LayoutInput {
        LayoutInput(axis: axis, travel: .room, throwing: throwing, swipes: true)
    }

    /// The travel `pointsPerUnit` says: so many points, one at least, or the view in front's.
    private static func travel(_ pointsPerUnit: Double?) -> Travel {
        pointsPerUnit.map { .points(max($0, 1)) } ?? .front
    }
}

extension LayoutInput.Axis: HostRepresentable {}
