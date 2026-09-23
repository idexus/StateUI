// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports: one typed value per part of its payload.
// Design: docs/design/types/gestures.md#one-typed-value-per-part

/// One report from a pan - what `.onPanUpdated` hands its handler.
///
///     ColorBox(.cornflowerBlue)
///         .translationX(offsetX)
///         .onPanUpdated { pan in
///             if pan.phase == .running { offsetX = pan.totalX }
///         }
///
/// One of these arrives per movement, each carrying `phase` and how far the
/// finger has come since the pan began.
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

    /// One report, from the three values a pan carries: phase, totalX, totalY.
    init(phase: GesturePhase, totalX: Double, totalY: Double) {
        self.phase = phase
        self.totalX = totalX
        self.totalY = totalY
    }
}
