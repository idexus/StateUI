// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports: one typed value per part of its payload.
// Design: docs/design/types/gestures.md#one-typed-value-per-part

/// One report from two fingers turning - what `.onRotationUpdated` hands its
/// handler.
///
///     Image("dial.png")
///         .rotation(angle)
///         .onRotationUpdated { turn in
///             if turn.phase == .began { turned = angle }
///             angle = turned + turn.angle
///         }
///
/// `angle` is how far the fingers have turned since they began, as a pan
/// reports its totals, so a handler turns what it held when they began.
public struct RotationUpdate: Equatable, Sendable {
    /// How far along the rotation is.
    public var phase: GesturePhase

    /// How far the fingers have turned since they began, in degrees,
    /// clockwise.
    public var angle: Double

    /// How fast they turn, in degrees a second, clockwise - at an end, as fast
    /// as they lifted; nought as they begin.
    ///
    /// Design: docs/design/types/gestures.md#a-gestures-speed
    public var velocity: Double

    /// One report, from the three values a rotation carries: phase, angle and speed.
    init(phase: GesturePhase, angle: Double, velocity: Double) {
        self.phase = phase
        self.angle = angle
        self.velocity = velocity
    }
}
