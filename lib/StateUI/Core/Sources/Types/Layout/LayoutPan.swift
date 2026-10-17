// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The hand moving a layout engine's phase every way: one axis across, another down. This library's own.
///
///     LayoutEngine(tiles, id: \.name) { … } placements: { room, table in … }
///         .phase($table)
///         .input(.pan, drives: \.x, \.y)
///
/// Design: docs/design/views/layout-engine.md#a-pan
public struct LayoutPan: Equatable, Sendable {
    /// How far the hand travels for one unit of either axis.
    let travel: LayoutInput.Travel

    /// How a throw goes on once the hand lets go: how far it carries, and the curve it slows on.
    public let throwing: Motion

    /// A finger or a pointer dragged, a trackpad's two fingers and a wheel over the views, whichever way they go: the
    /// across axis moves with the hand across, the down axis with the hand down - a hand moving left and up moves
    /// both on, as far as the view drawn in front moves for one unit of that axis. Let go with speed, the run is
    /// thrown on to the snap target nearest where the throw would end, both axes together, with a light friction;
    /// let go still, onto the nearest. Two fingers carry it by their middle as they spread and turn, so a
    /// magnification and a rotation move at once.
    ///
    ///     .input(.pan, drives: \.x, \.y)
    public static var pan: LayoutPan {
        LayoutPan(travel: .front, throwing: .eased(.milliseconds(400), .cubicOut))
    }

    /// The same, the hand travelling `pointsPerUnit` device units for one unit of either axis - one at least.
    ///
    ///     .input(.pan(pointsPerUnit: 240), drives: \.x, \.y)
    ///
    /// - Parameters:
    ///   - pointsPerUnit: how far the hand travels for one unit of either axis, in device units.
    ///   - throwing: how a throw goes on; a light friction unless said.
    /// - Returns: the input.
    public static func pan(
        pointsPerUnit: Double, throwing: Motion = .eased(.milliseconds(400), .cubicOut)
    ) -> LayoutPan {
        LayoutPan(travel: LayoutInput.travel(pointsPerUnit), throwing: throwing)
    }

    /// The same, thrown on as `throwing` says.
    ///
    ///     .input(.pan(throwing: .spring(response: .milliseconds(500), damping: 0.8)), drives: \.x, \.y)
    ///
    /// - Parameter throwing: how a throw goes on.
    /// - Returns: the input.
    public static func pan(throwing: Motion) -> LayoutPan {
        LayoutPan(travel: .front, throwing: throwing)
    }
}
