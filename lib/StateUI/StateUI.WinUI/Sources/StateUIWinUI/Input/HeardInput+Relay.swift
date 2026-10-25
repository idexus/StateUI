// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI
import StateUIFoundation

/// What a view heard of the user's input, as the relay tells it.
/// Design: docs/design/platforms/winui/input.md
extension HeardInput {
    /// What the relay's callback says - `phase` a gesture's phase, or 1 where a finger is the pointer, a pinch's
    /// `scale` since its last step, a rotation's degrees clockwise in its place, a wheel's notches turned with
    /// Control in its place - nil for a press, a tap and a hold, which the view's own rules read (`heardPress`,
    /// `heardTap`, `heardHold`, `heardButtonPress`) - and a tap assistive technology made.
    init?(_ what: StateUIHeard, phase: Int32, x: Double, y: Double, scale: Double) {
        let point = Point(x: x, y: y)
        let byFinger = phase == 1
        switch what {
        case .tap, .press, .hold, .buttonPress, .invoked: return nil
        case .pointerEntered: self = .pointer(.pointerEntered, point, byFinger: byFinger)
        case .pointerExited: self = .pointer(.pointerExited, point, byFinger: byFinger)
        case .pointerMoved: self = .pointer(.pointerMoved, point, byFinger: byFinger)
        case .pointerPressed: self = .pointer(.pointerPressed, point, byFinger: byFinger)
        case .pointerReleased: self = .pointer(.pointerReleased, point, byFinger: byFinger)
        case .pinch:
            guard let phase = GesturePhase(rawValue: phase) else { return nil }
            self = .pinch(phase, scale: scale, at: point)
        case .rotation:
            guard let phase = GesturePhase(rawValue: phase) else { return nil }
            self = .rotation(phase, degrees: scale)
        case .wheelPinch: self = .wheelPinch(scale: pow(WheelPinch.notch, scale), at: point)
        case .wheelScale: self = .wheelPinch(scale: scale, at: point)
        }
    }
}
