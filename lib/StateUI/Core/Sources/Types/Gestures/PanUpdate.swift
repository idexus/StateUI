// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports: one typed value per part of its payload.
// Design: docs/design/types/gestures.md#one-typed-value-per-part

/// One report from a pan - what `.onPanUpdated` hands its handler.
///
///     Rectangle()
///         .fill(.cornflowerBlue)
///         .translationX(offsetX)
///         .onPanUpdated { pan in
///             if pan.phase == .changed { offsetX = pan.totalX }
///         }
///
/// One of these arrives per movement, each carrying `phase`, how far the
/// finger has come since the pan began, and how fast it goes - what a
/// journey goes on at once the finger lifts:
///
///     .onPanUpdated { pan in
///         if pan.phase == .ended { $offsetX.journey.velocity = pan.velocityX }
///     }
public struct PanUpdate: Equatable, Sendable {
    /// How far along the pan is.
    public var phase: GesturePhase

    /// How far the pointer has moved sideways since the pan began, in device
    /// units.
    public var totalX: Double

    /// The same, vertically.
    ///
    /// Both totals are measured from where the pan began, on every platform,
    /// so assigning them to a translation moves the view with the finger.
    ///
    /// Design: docs/design/types/gestures.md#a-pan-is-measured-from-its-start
    public var totalY: Double

    /// How fast the pointer moves sideways, in device units a second - at an
    /// end, as fast as it lifted; nought as the pan begins.
    ///
    /// Design: docs/design/types/gestures.md#a-gestures-speed
    public var velocityX: Double

    /// The same, vertically.
    public var velocityY: Double

    /// One report, from the three values a pan carries: its phase, how far it came and how fast it goes.
    init(phase: GesturePhase, total: Point, velocity: Point) {
        self.phase = phase
        totalX = total.x
        totalY = total.y
        velocityX = velocity.x
        velocityY = velocity.y
    }
}
