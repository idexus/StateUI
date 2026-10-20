// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI
import StateUIFoundation

/// What a view heard of the user's input, as the relay tells it.
/// Design: docs/design/platforms/winui/input.md
extension HeardInput {
    /// What the relay's callback says - `phase` a gesture's phase, a pinch's `scale` since its last step, a
    /// rotation's degrees clockwise in its place, a wheel's notches turned with Control in its place - nil for a
    /// press and a tap, which the view's own rules read (`heardPress`, `heardTap`).
    init?(_ what: StateUIHeard, phase: Int32, x: Double, y: Double, scale: Double) {
        let point = Point(x: x, y: y)
        switch what {
        case .tap, .press: return nil
        case .pointerEntered: self = .pointer(.pointerEntered, point)
        case .pointerExited: self = .pointer(.pointerExited, point)
        case .pointerMoved: self = .pointer(.pointerMoved, point)
        case .pointerPressed: self = .pointer(.pointerPressed, point)
        case .pointerReleased: self = .pointer(.pointerReleased, point)
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
