// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The fingers on a layout a hand moves, as a toolkit tells each - down, moved, up, by its number and where it stands
/// - read as one hand at their middle (`PointerMiddle`), the same on every host whose toolkit tells fingers and no
/// pan of its own: the first finger down begins it where it went down in the view; its first move past the
/// platform's distance asks the layout whether it takes the hand; a hand taken says every move after; the last finger
/// up ends it, taken or not.
/// Design: docs/design/host/runtime.md#the-hand-over-a-layout
@_spi(Host) public struct HandRecognition: Sendable {
    /// What a finger's report says of the hand.
    public enum Step: Equatable, Sendable {
        /// Nothing to tell.
        case nothing

        /// The hand began, a press down at this point in the view.
        case began(at: Point)

        /// The hand moved this far past the platform's distance: the layout says whether it takes it
        /// (`answered(taken:)`).
        case asks(Point)

        /// The hand the layout took moved what is under it by this step.
        case moved(Point)

        /// The last finger lifted - or, not let go, the platform took the hand away.
        case ended(letGo: Bool)
    }

    /// How far the hand moves before it asks, as the platform measures it.
    public let distance: DragRecognition.Distance

    /// Whether the layout took the hand.
    public private(set) var isTaken = false

    /// Whether the hand is the layout's, or may yet be: it took it, or the hand has not asked yet.
    public var isOpen: Bool { asking || isTaken }

    private var fingers = PointerMiddle()
    private var travel = Point(x: 0, y: 0)
    private var asking = false

    /// No finger down, a hand asking past `distance`.
    public init(distance: DragRecognition.Distance) {
        self.distance = distance
    }

    /// A finger went down at `point`, at `inView` in the view: the first begins the hand there; another joins it,
    /// moving its middle nowhere.
    public mutating func down(_ finger: Int, at point: Point, inView: Point) -> Step {
        let first = fingers.count == 0
        fingers.down(finger, at: point)
        guard first else { return .nothing }

        travel = Point(x: 0, y: 0)
        asking = true
        isTaken = false
        return .began(at: inView)
    }

    /// A finger moved to `point`: the hand's middle moves by its step over how many are down - asking once past the
    /// distance, and said once the layout took it.
    public mutating func moved(_ finger: Int, to point: Point) -> Step {
        guard asking || isTaken else { return .nothing }

        let step = fingers.moved(finger, to: point)
        guard asking else { return step == Point(x: 0, y: 0) ? .nothing : .moved(step) }

        travel = Point(x: travel.x + step.x, y: travel.y + step.y)
        guard distance.isPassed(by: travel) else { return .nothing }

        asking = false
        return .asks(travel)
    }

    /// The layout said whether it takes the hand that asked; one it leaves says no move after.
    public mutating func answered(taken: Bool) {
        isTaken = taken
    }

    /// A finger lifted - or, not `letGo`, the platform took it away: the last ends the hand.
    public mutating func up(_ finger: Int, letGo: Bool) -> Step {
        guard fingers.count > 0 else { return .nothing }

        fingers.up(finger)
        guard fingers.count == 0 else { return .nothing }

        asking = false
        isTaken = false
        return .ended(letGo: letGo)
    }
}
