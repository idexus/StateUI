// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// What a view heard of the user's input, as the relay tells it.
/// Design: docs/design/platforms/winui/input.md
extension HeardInput {
    /// What the relay's callback says - `phase` a tap's place in its run or a gesture's phase, a pinch's `scale`
    /// since its last step - nil for what it does not name.
    init?(_ what: StateUIHeard, phase: Int32, x: Double, y: Double, scale: Double) {
        let point = Point(x: x, y: y)
        switch what {
        case StateUIHeardTap: self = .tap(run: Int(phase))
        case StateUIHeardPointerEntered: self = .pointer(.pointerEntered, point)
        case StateUIHeardPointerExited: self = .pointer(.pointerExited, point)
        case StateUIHeardPointerMoved: self = .pointer(.pointerMoved, point)
        case StateUIHeardPointerPressed: self = .pointer(.pointerPressed, point)
        case StateUIHeardPointerReleased: self = .pointer(.pointerReleased, point)
        case StateUIHeardPinch:
            guard let phase = GesturePhase(rawValue: phase) else { return nil }
            self = .pinch(phase, scale: scale, at: point)
        default: return nil
        }
    }
}
