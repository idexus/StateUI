// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// What a view heard of the user's input, as the relay tells it.
/// Design: docs/design/platforms/winui/input.md
enum WinUIHeard: Equatable, Sendable {
    /// A tap: its place in a quick run of taps, from 1; 0 for a press assistive technology made.
    case tap(run: Int)

    /// The pointer over the view: the View tier's event, and where it is, in DIPs of the view.
    case pointer(Event, Point)

    /// A press dragged: its phase - 0 began, 1 moved, 2 ended, 3 cancelled - and how far it has moved since it began.
    case drag(phase: Int32, x: Double, y: Double)

    /// A pinch: its phase, its scale since the last, and where, as shares of the view's size.
    case pinch(phase: Int32, scale: Double, at: Point)

    /// What the relay's callback says; nil for what it does not name.
    init?(_ what: StateUIHeard, phase: Int32, x: Double, y: Double, scale: Double) {
        let point = Point(x: x, y: y)
        switch what {
        case StateUIHeardTap: self = .tap(run: Int(phase))
        case StateUIHeardPointerEntered: self = .pointer(.pointerEntered, point)
        case StateUIHeardPointerExited: self = .pointer(.pointerExited, point)
        case StateUIHeardPointerMoved: self = .pointer(.pointerMoved, point)
        case StateUIHeardPointerPressed: self = .pointer(.pointerPressed, point)
        case StateUIHeardPointerReleased: self = .pointer(.pointerReleased, point)
        case StateUIHeardDrag: self = .drag(phase: phase, x: x, y: y)
        case StateUIHeardPinch: self = .pinch(phase: phase, scale: scale, at: point)
        default: return nil
        }
    }
}
