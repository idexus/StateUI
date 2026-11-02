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
///             if pan.phase == .changed { offsetX = pan.total.x }
///         }
///
/// One of these arrives per movement, each carrying `phase`, how far the
/// press has come since the pan began, how fast it goes - what a journey goes
/// on at once the finger lifts - and where it is now:
///
///     .onPanUpdated { pan in
///         if pan.phase == .ended { $offsetX.journey.velocity = pan.velocity.x }
///     }
public struct PanUpdate: Equatable, Sendable {
    /// How far along the pan is.
    public var phase: GesturePhase

    /// How far the press has moved since the pan began, across and down, in device units.
    ///
    /// Measured from where the pan began, on every platform, so assigning it to a translation moves the view with
    /// the finger.
    ///
    /// Design: docs/design/types/gestures.md#a-pan-is-measured-from-its-start
    public var total: Point

    /// How fast the press moves, across and down, in device units a second - at an end, as fast as it lifted;
    /// nought as the pan begins.
    ///
    /// Design: docs/design/types/gestures.md#a-gestures-speed
    public var velocity: Point

    /// Where the press is now, in the view's own points from its top left - where a drawing puts its next stroke.
    public var at: Point

    /// One report, from the four values a pan carries: its phase, how far it came, how fast it goes and where it is.
    init(phase: GesturePhase, total: Point, velocity: Point, at: Point) {
        self.phase = phase
        self.total = total
        self.velocity = velocity
        self.at = at
    }
}
