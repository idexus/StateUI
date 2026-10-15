// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What moves a layout engine's phase under the user's hand. This library's own.
///
///     LayoutEngine(cards, id: \.name) { … } placements: { room, phase in … }
///         .phase($turn)
///         .input(.scroll(.horizontal, pointsPerUnit: 90))
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

    /// How far the hand travels for one unit of the phase, in device units.
    public let pointsPerUnit: Double

    /// How a throw goes on once the hand lets go: how far it carries, and the curve it slows on.
    public let throwing: Motion

    /// The hand over the views: a finger or a pointer dragged, a trackpad's two fingers and a wheel move the phase
    /// with them; let go with speed, the run is thrown on to the snap target nearest where the throw would end, as
    /// `throwing` says, and let go still it slides to the nearest under the layout's motion.
    ///
    ///     .input(.scroll(.horizontal, pointsPerUnit: 90, throwing: .eased(.milliseconds(400), .sineOut)))
    ///     .input(.scroll(.horizontal, pointsPerUnit: 90, throwing: .spring(response: .milliseconds(500), damping: 0.7)))
    ///
    /// - Parameters:
    ///   - axis: which way it scrolls.
    ///   - pointsPerUnit: how far the hand travels for one unit of the phase, in device units; one at least.
    ///   - throwing: how a throw goes on. Eased, its length says how far it carries - the hand's speed for that long,
    ///     over how steeply the curve sets out - and the curve how it slows; a spring carries the hand's speed for
    ///     a third of its response, and settles as springs do. Either sets out at the hand's speed, so a throw never
    ///     speeds up after the lift. A light friction unless said.
    /// - Returns: the input.
    public static func scroll(
        _ axis: Axis, pointsPerUnit: Double, throwing: Motion = .eased(.milliseconds(400), .cubicOut)
    ) -> LayoutInput {
        LayoutInput(axis: axis, pointsPerUnit: max(pointsPerUnit, 1), throwing: throwing)
    }
}

extension LayoutInput.Axis: HostRepresentable {}
