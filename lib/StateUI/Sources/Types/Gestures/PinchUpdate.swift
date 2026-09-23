// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports: one typed value per part of its payload.
// Design: docs/design/types/gestures.md#one-typed-value-per-part

/// One report from a pinch - what `.onPinchUpdated` hands its handler.
///
///     Image("map.png")
///         .scale(zoom)
///         .onPinchUpdated { pinch in zoom *= pinch.scale }
///
/// `scale` is how much the fingers moved since the LAST report, so a handler
/// multiplies what it holds rather than assigning.
public struct PinchUpdate: Equatable, Sendable {
    /// How far along the pinch is.
    public var phase: GesturePhase

    /// How much the fingers have moved apart since the last report. The scale
    /// is relative, not cumulative.
    public var scale: Double

    /// Where the pinch is centred, as a fraction of the view: (0,0) is the top
    /// left and (1,1) the bottom right.
    public var scaleOrigin: Point

    /// One report, from the three values a pinch carries: phase, scale, and
    /// the origin.
    init(phase: GesturePhase, scale: Double, scaleOrigin: Point) {
        self.phase = phase
        self.scale = scale
        self.scaleOrigin = scaleOrigin
    }
}
