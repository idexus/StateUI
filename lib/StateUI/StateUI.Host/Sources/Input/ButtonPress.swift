// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A press on a view that hears taps, taken as a button takes one, the same on every host: the view is lit while
/// the press stands over it - out as it leaves, lit again as it comes back - and tapped where the press lets go over
/// it; let go away, or taken by a scroll or a drag, it taps nothing. A finger's press in a scroller lights the view
/// only once it has stood a moment, as it may still begin a scroll.
/// Design: docs/design/host/runtime.md#a-press-as-a-button-takes-it
@_spi(Host) public struct ButtonPress: Equatable, Sendable {
    /// What one step of a press says of the view.
    public enum Said: Equatable, Sendable {
        /// The view is lit: pressed, the press over it.
        case lit
        /// The view is out again.
        case out
        /// The press let go over the view: a tap.
        case tapped
    }

    /// How far beyond a view's edge a finger still stands over it, in points; a mouse or a pen stands over it within
    /// its edge.
    public static let fingerBreadth = 10.0

    /// Whether a press stands on the view.
    public private(set) var isPressed = false

    /// Whether the view is lit.
    public private(set) var isLit = false

    /// How long a finger's press in a scroller stands before it lights the view, in seconds: iOS's wait before a
    /// list's row hears a touch that may still begin a scroll.
    public static let scrollerWait = 0.15

    /// When the press began, while it waits to light the view, and whether it stands over it.
    private var waitingSince: Double?
    private var over = false

    /// Whether the press waits to light the view.
    public var isWaiting: Bool { waitingSince != nil }

    /// No press yet: the view out.
    public init() {}

    /// Whether a press at `point`, in points of a view `size`, stands over it.
    public static func isOver(_ point: Point, in size: LayoutSize, byFinger: Bool) -> Bool {
        let beyond = byFinger ? fingerBreadth : 0
        return point.x >= -beyond && point.y >= -beyond
            && point.x <= size.width + beyond && point.y <= size.height + beyond
    }

    /// The press at `phase`, `over` the view or away from it, beginning at `now` - waiting a moment before it lights
    /// the view where it `waits`: what it says of the view.
    public mutating func step(_ phase: GesturePhase, over: Bool, waits: Bool = false, at now: Double = 0) -> [Said] {
        self.over = over
        switch phase {
        case .began:
            isPressed = true
            guard !waits else {
                waitingSince = now
                return []
            }
            waitingSince = nil
            return light(over)
        case .changed:
            return isPressed && waitingSince == nil ? light(over) : []
        case .ended:
            guard isPressed else { return [] }
            isPressed = false
            // A quick tap in a scroller lights the view as it lets go.
            let lit = waitingSince != nil && over ? light(true) : []
            waitingSince = nil
            return lit + light(false) + (over ? [.tapped] : [])
        case .cancelled:
            isPressed = false
            waitingSince = nil
            return light(false)
        }
    }

    /// A frame at `now`: a press that has waited long enough lights the view where it stands over it.
    public mutating func paced(now: Double) -> [Said] {
        guard let since = waitingSince, now - since >= Self.scrollerWait - 1e-9 else { return [] }
        waitingSince = nil
        return light(over)
    }

    private mutating func light(_ lit: Bool) -> [Said] {
        guard lit != isLit else { return [] }
        isLit = lit
        return [lit ? .lit : .out]
    }
}
