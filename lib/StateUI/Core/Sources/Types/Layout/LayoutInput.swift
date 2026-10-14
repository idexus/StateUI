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
    public enum Axis: Equatable, Sendable {
        /// Across: a finger or a wheel moving sideways, the phase growing to the right.
        case horizontal

        /// Down: a finger or a wheel moving up and down, the phase growing downwards.
        case vertical
    }

    /// Which way the hand moves the phase.
    public let axis: Axis

    /// How far the hand travels for one unit of the phase, in device units.
    public let pointsPerUnit: Double

    /// An empty scroller over the views, its offset the phase: a finger, a trackpad and a wheel move it with the
    /// platform's own physics, and a pointer dragged on a desktop moves it too.
    ///
    /// - Parameters:
    ///   - axis: which way it scrolls.
    ///   - pointsPerUnit: how far the hand travels for one unit of the phase, in device units; one at least.
    /// - Returns: the input.
    public static func scroll(_ axis: Axis, pointsPerUnit: Double) -> LayoutInput {
        LayoutInput(axis: axis, pointsPerUnit: max(pointsPerUnit, 1))
    }
}
