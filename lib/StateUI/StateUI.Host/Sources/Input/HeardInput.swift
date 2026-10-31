// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a view heard of the user's input, as a host's toolkit tells it, in the contract's terms.
/// Design: docs/design/host/runtime.md#what-the-user-does-with-a-finger
@_spi(Host) public enum HeardInput: Equatable, Sendable {
    /// A tap: its place in a quick run of taps, from 1; 0 for a press assistive technology made.
    case tap(run: Int)

    /// A press held as long as the view's hold waits, before it moved as far as a drag.
    case hold

    /// A press on a view that hears taps, as a button takes one (`ButtonPress`): its phase, where it stands in points
    /// of the view, the view's size, and whether a finger presses - which stands over the view a little beyond it.
    case press(GesturePhase, at: Point, size: LayoutSize, byFinger: Bool)

    /// The pointer over the view: the View tier's event, where it is, in points of the view, and whether a finger
    /// is the pointer - which presses and lets go, and hovers over nothing.
    case pointer(Event, Point, byFinger: Bool = false)

    /// A press dragged: its phase, and how far it has moved since it began.
    case drag(GesturePhase, x: Double, y: Double)

    /// A pinch: its phase, its scale since the last step, and where, as shares of the view's size.
    case pinch(GesturePhase, scale: Double, at: Point)

    /// Two fingers turning: its phase, and how far they turned since the last step, in degrees clockwise.
    case rotation(GesturePhase, degrees: Double)

    /// A press dragged with ⌥/Alt over a view two fingers move: its phase, where it is and where the view's middle
    /// is, in points of the view - two fingers, the press and its mirror about the middle (`MirroredFingers`).
    case mirrored(GesturePhase, at: Point, middle: Point)

    /// A wheel turned as a pinch - with Control, as a platform tells a trackpad's pinch to an application that hears
    /// no gesture of it: the scale of this turn, and where, as shares of the view's size (`WheelPinch`).
    case wheelPinch(scale: Double, at: Point)

    /// The hand over a layout - a press dragged or a trackpad's fingers: its phase, how far it moved what is under
    /// it since the last report, as it lifts its speed, per second, where the platform tells one, when the platform
    /// says it happened, in the frame clock's milliseconds, where it says so, and - a press beginning - where it
    /// went down, in points of the view.
    case hand(GesturePhase, moved: Point, speed: Point?, at: Double? = nil, point: Point? = nil)

    /// A wheel's step over a layout: how far it moved what is under the hand - a stream of them, a trackpad's.
    case wheel(Point)

    /// A wheel's notches over a layout, as many as it turned, across and down, the way they move what is under the
    /// hand - where the platform says the wheel turns notch by notch; a part of one where it turns finer.
    case notch(Point)

    /// A drag of the view between views started.
    case dragStarted

    /// A drag of the view between views ended, wherever it ended.
    case dragEnded

    /// A drag between views is over the view, however often the toolkit says so.
    case dragOver

    /// A drag between views went away from the view without being let go.
    case dragLeft

    /// A drag between views was let go over the view, carrying these words.
    case dropped(String)

    /// Files the user dragged from the system were let go over the view - every one of them, of whatever kind.
    case filesDropped([ChosenFile])

    /// A screen reader performed one of the view's actions, named by its words.
    case accessibilityAction(String)

    /// A screen reader stepped the view up or down.
    case accessibilityAdjustment(AccessibilityAdjustment)
}

/// What a view listens for of the user's input.
@_spi(Host) public struct Hearing: OptionSet, Hashable, Sendable {
    /// The set's bits, one a kind of input.
    public let rawValue: UInt32

    /// Makes a set from its bits.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Taps, counted in quick runs.
    public static let taps = Hearing(rawValue: 1 << 0)

    /// The pointer entering, moving, pressing, releasing and leaving.
    public static let pointer = Hearing(rawValue: 1 << 1)

    /// A press dragged.
    public static let drags = Hearing(rawValue: 1 << 2)

    /// A pinch.
    public static let pinches = Hearing(rawValue: 1 << 3)

    /// The hand over a layout: a press dragged, a trackpad's fingers and a wheel, the layout's way (`handWay`).
    public static let hand = Hearing(rawValue: 1 << 4)

    /// Two fingers turning: over a layout that `rotates`.
    public static let rotations = Hearing(rawValue: 1 << 5)

    /// A press held.
    public static let holds = Hearing(rawValue: 1 << 6)

    /// Each kind of input on its own.
    public static let kinds: [Hearing] = [.taps, .pointer, .drags, .pinches, .hand, .rotations, .holds]
}

/// A pinch's steps: each step's scale since the last, of a pinch a toolkit tells as its whole scale.
@_spi(Host) public struct PinchStep: Sendable {
    private var last = 1.0

    /// A pinch not begun.
    public init() {}

    /// The scale since the last step of a pinch standing at `scale` in `phase`: 1 as it begins and ends.
    public mutating func step(_ phase: GesturePhase, scale: Double) -> Double {
        let step = phase == .changed && last > 0 ? scale / last : 1
        last = phase == .changed ? scale : 1
        return step
    }

    /// Where `point` stands as shares of a view `width` by `height`: its middle where there is no point or no size.
    public static func share(of point: Point?, width: Double, height: Double) -> Point {
        guard let point, width > 0, height > 0 else { return Point(x: 0.5, y: 0.5) }
        return Point(x: point.x / width, y: point.y / height)
    }
}
