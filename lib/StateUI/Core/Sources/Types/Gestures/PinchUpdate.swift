// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports: one typed value per part of its payload.
// Design: docs/design/types/gestures.md#one-typed-value-per-part

/// One report from a pinch - what `.onPinchUpdated` hands its handler.
///
///     Image("map.png")
///         .scale(zoom)
///         .onPinchUpdated { pinch in
///             if pinch.phase == .began { zoomed = zoom }
///             zoom = zoomed * pinch.scale
///         }
///
/// `scale` is how far the fingers have spread since the pinch began, so a
/// handler scales what it held when the pinch began.
public struct PinchUpdate: Equatable, Sendable {
    /// How far along the pinch is.
    public var phase: GesturePhase

    /// How far the fingers have spread since the pinch began: 1 at its start, 2
    /// twice as far apart - as a pan reports its totals.
    public var scale: Double

    /// Where the pinch is centered, as a fraction of the view: (0,0) is the top
    /// left and (1,1) the bottom right.
    public var scaleOrigin: Point

    /// How fast the scale changes, a second - at an end, as fast as the
    /// fingers lifted; nought as the pinch begins.
    ///
    /// Design: docs/design/types/gestures.md#a-gestures-speed
    public var velocity: Double

    /// One report, from the four values a pinch carries: phase, scale, the
    /// origin and the speed.
    init(phase: GesturePhase, scale: Double, scaleOrigin: Point, velocity: Double) {
        self.phase = phase
        self.scale = scale
        self.scaleOrigin = scaleOrigin
        self.velocity = velocity
    }
}
