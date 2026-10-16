// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The hand over a layout engine, read alike on every host: a press dragged or a trackpad's fingers reported as they
/// move, a wheel's notches with no lift - ended after a pause on the frame clock - and the speed at the lift where
/// the platform tells none. What it answers is the element's `handMoved`.
/// Design: docs/design/host/runtime.md#the-hand-over-a-layout
@_spi(Host) public struct HandReading: Sendable {
    /// One report of the hand: its phase, how far it moved what is under it since the last, and its speed as it
    /// lifts, per second; a hand holding one view by itself, where it is and how long it has stood still.
    public struct Report: Equatable, Sendable {
        /// Where the gesture is: begun, moving, lifted or taken away.
        public let phase: GesturePhase

        /// How far the hand moved what is under it since the last report.
        public let moved: Point

        /// How fast the hand went as it lifted, per second; nought before.
        public let speed: Point

        /// Whether the hand holds one view by itself rather than moving the run.
        public let item: Bool

        /// Where a hand holding a view is, in points of the layout.
        public let at: Point

        /// How long a hand holding a view has stood still, in milliseconds.
        public let still: Double

        /// A report of `phase`.
        public init(
            _ phase: GesturePhase, moved: Point = .zero, speed: Point = .zero, item: Bool = false, at: Point = .zero,
            still: Double = 0
        ) {
            self.phase = phase
            self.moved = moved
            self.speed = speed
            self.item = item
            self.at = at
            self.still = still
        }

        /// The same report, of the hand holding a view at `at`.
        func holding(at: Point) -> Report {
            Report(phase, moved: moved, speed: speed, item: true, at: at, still: still)
        }
    }

    /// How long a wheel stands still before it counts as let go, in milliseconds.
    public static let pause = 150.0

    /// How far back the speed at a lift is read, in milliseconds.
    public static let reading = 100.0

    /// The shortest time a speed is read over, in milliseconds: a display frame.
    public static let frame = 16.0

    /// How long a press stands still before it holds the view under it, in milliseconds: the long press the
    /// platforms share closely enough.
    public static let hold = 500.0

    /// How many steps of a wheel, each slower than the last, say it was let go: a trackpad's momentum.
    public static let fade = 3

    /// How far back a wheel's pace is read, in milliseconds - four frames: steps come late, glued together or
    /// uneven, and their sum over a window says how fast the hand goes where one step alone does not.
    public static let window = 64.0

    /// The longest the momentum goes without a step, in milliseconds - six frames: a step after a longer gap is a
    /// hand that stopped it and moves again.
    public static let gap = 100.0

    /// How much faster than the momentum at its slowest the wheel must go to be a hand pushing again.
    public static let surge = 1.5

    /// The least a step moves, in points, to count toward a push or a fade: a slow hand and the momentum's tail
    /// creep a few points a frame, slowing and quickening by chance, and the system makes a momentum of none of it.
    public static let least = 8.0

    /// Whether a gesture is under way, and whether it is a wheel's.
    private var open = false
    public private(set) var isWheeling = false

    /// Whose the gesture the platform tells is: nil until its first move says. Kept after its lift, so what the
    /// platform tells after it - a trackpad's momentum - goes where the gesture went.
    public private(set) var claimed: Bool?

    /// Where a press went down and when, while nobody has it yet, and how a view of the layout is taken by itself.
    private var press: (point: Point, time: Double)?
    private var itemStart: ItemDragStart?

    /// Whether the hand holds one view by itself, where it is, when it last moved on the frames' clock, and how many
    /// long presses it has stood still since, each told.
    public private(set) var holdsItem = false
    private var itemAt = Point.zero
    private var itemMovedAt = 0.0
    private var stood = 0

    /// Whether the hand asks the frames for something: a wheel to let go, a press to hold a view, a held view
    /// standing still.
    public var wantsFrames: Bool {
        isWheeling || holdsItem || (press != nil && itemStart == .held && claimed == nil)
    }

    /// The moves of the last `reading` milliseconds, with when each was made.
    private var moves: [(time: Double, moved: Point)] = []

    /// When the hand last moved.
    private var last = 0.0

    /// The part of a notch a fine wheel has turned toward the next, along the layout's axis.
    private var turned = 0.0

    /// A wheel's steps of the last `window`, how fast they went - their sum over the window - which way, how many
    /// steps in a row went slower than the one before, and whether what still comes is the momentum after a lift,
    /// swallowed, with how fast it went at its slowest.
    private var steps: [(time: Double, size: Double)] = []
    private var pace = 0.0
    private var heading = Point.zero
    private var trough = 0.0
    private var fading = 0
    private var coasting = false

    /// A hand not begun.
    public init() {}

    /// Whether a layout moved along `axis` claims the hand whose first move is `moved`: one more along the axis
    /// than across it. A hand not yet moving is claimed by nobody.
    public static func claims(_ moved: Point, along axis: LayoutInput.Axis) -> Bool {
        let along = abs(axis == .horizontal ? moved.x : moved.y)
        let across = abs(axis == .horizontal ? moved.y : moved.x)
        return along > 0 && along >= across
    }

    /// Whether a hand whose first move is `moved` is taken over a layout moved along `axis` whose views are taken as
    /// `items` says - the run's along it, a view's across it with `.across` - and any way where it already holds a
    /// view: what a toolkit asks before its drag begins.
    public static func takes(
        _ moved: Point, along axis: LayoutInput.Axis?, items: ItemDragStart?, holding: Bool
    ) -> Bool {
        holding || axis.map { claims(moved, along: $0) } == true || (items == .across && moved != .zero)
    }

    /// The hand at `phase` - a press dragged or a trackpad's fingers - moving what is under it by `moved` at `time`,
    /// lifting at `speed` where the platform tells one, a press going down at `point`: a layout moved along `axis`
    /// takes a gesture whose first move is along it; one whose views are taken as `items` says gives the view under
    /// the press a first move across it (`.across`) or a press standing still `hold` (`.held`, by the frames); the
    /// rest is left to whatever holds the layout. A hold and a held view's standing are measured on the frames'
    /// clock, `now`; the hand's pace on the platform's, `time`. Whether it took this step, and what it says.
    /// Design: docs/design/host/runtime.md#the-hand-over-a-layout
    public mutating func hand(
        _ phase: GesturePhase, moved: Point, speed: Point?, at time: Double, along axis: LayoutInput.Axis?,
        point: Point? = nil, items: ItemDragStart? = nil, now: Double? = nil
    ) -> (taken: Bool, reports: [Report]) {
        let now = now ?? time
        switch phase {
        case .began:
            claimed = nil
            holdsItem = false
            itemStart = items
            press = point.map { ($0, now) }
            return (true, [])

        case .changed:
            if holdsItem { return (true, itemMoved(moved, at: time, now: now)) }
            if claimed == nil {
                guard moved != .zero else { return (true, []) }

                claimed = axis.map { Self.claims(moved, along: $0) } ?? false
                if claimed == true {
                    press = nil
                    return (true, began(at: time) + self.moved(moved, at: time))
                }
                guard itemStart == .across, let press else {
                    self.press = nil
                    return (false, [])
                }
                return (true, itemTaken(at: press.point, time: time, now: now) + itemMoved(moved, at: time, now: now))
            }
            guard claimed == true else { return (false, []) }

            return (true, self.moved(moved, at: time))

        case .ended, .cancelled:
            press = nil
            if holdsItem {
                holdsItem = false
                let at = itemAt
                return (true, (phase == .ended ? lifted(at: time, speed: speed) : cancelled()).map { $0.holding(at: at) })
            }
            guard claimed == true else { return (false, []) }

            return (true, phase == .ended ? lifted(at: time, speed: speed) : cancelled())
        }
    }

    /// The press holds the view under `point` at `time`, `now` on the frames' clock: the hand is that view's to its
    /// lift.
    private mutating func itemTaken(at point: Point, time: Double, now: Double) -> [Report] {
        press = nil
        holdsItem = true
        itemAt = point
        itemMovedAt = now
        stood = 0
        return began(at: time).map { $0.holding(at: point) }
    }

    /// The hand holding a view moved it by `moved` at `time`, `now` on the frames' clock.
    private mutating func itemMoved(_ moved: Point, at time: Double, now: Double) -> [Report] {
        itemAt = Point(itemAt.x + moved.x, itemAt.y + moved.y)
        itemMovedAt = now
        stood = 0
        return self.moved(moved, at: time).map { $0.holding(at: itemAt) }
    }

    /// A wheel's notch moving what is under the hand by `moved` at `time`, over a layout moved along `axis`: taken
    /// where it moves along the axis. Whether it was, and what it says.
    public mutating func wheel(_ moved: Point, at time: Double, along axis: LayoutInput.Axis?) -> (taken: Bool, reports: [Report]) {
        guard let axis, Self.claims(moved, along: axis) else { return (false, []) }

        return (true, notched(moved, at: time))
    }

    /// A wheel's notches over a layout moved along `axis`, turned as `notches` says: taken where they turn along the
    /// axis, the whole notches they come to with what was turned before - a fine wheel's parts adding up - and
    /// none until they do.
    /// Design: docs/design/host/runtime.md#the-hand-over-a-layout
    public mutating func notches(_ notches: Point, along axis: LayoutInput.Axis?) -> (taken: Bool, steps: Point?) {
        guard let axis, Self.claims(notches, along: axis) else { return (false, nil) }

        turned += axis == .horizontal ? notches.x : notches.y
        let whole = turned.rounded(.towardZero)
        turned -= whole
        guard whole != 0 else { return (true, nil) }

        return (true, axis == .horizontal ? Point(whole, 0) : Point(0, whole))
    }

    /// Two fingers take the hand from the run, at `time`: a gesture under way lets go where it is, still, and what the
    /// platform tells of it after - a finger going on, its lift - is nobody's until a new press. A view held by itself
    /// keeps the hand.
    /// Design: docs/design/host/runtime.md#two-fingers-over-a-layout
    public mutating func yield(at time: Double) -> [Report] {
        guard !holdsItem else { return [] }

        press = nil
        claimed = false
        return lifted(at: time, speed: .zero)
    }

    /// The hand begins, at `time`: a wheel still open is let go first.
    public mutating func began(at time: Double) -> [Report] {
        let ended = isWheeling ? lifted(at: time, speed: .zero) : []

        open = true
        coasting = false
        moves = []
        last = time
        return ended + [Report(.began)]
    }

    /// The hand moved what is under it by `moved`, at `time`.
    public mutating func moved(_ moved: Point, at time: Double) -> [Report] {
        guard open else { return began(at: time) + self.moved(moved, at: time) }

        moves = moves.filter { time - $0.time <= Self.reading } + [(time, moved)]
        last = time
        return [Report(.changed, moved: moved)]
    }

    /// The hand lifted at `time`, as fast as the platform says, or as its last moves say where it says nothing.
    public mutating func lifted(at time: Double, speed: Point?) -> [Report] {
        guard open else { return [] }

        let recent = moves.filter { time - $0.time <= Self.reading }
        let span = max(time - (recent.first?.time ?? time), Self.frame)
        let went = recent.reduce(Point.zero) { Point($0.x + $1.moved.x, $0.y + $1.moved.y) }
        let read = recent.isEmpty ? Point.zero : Point(went.x / span * 1_000, went.y / span * 1_000)

        open = false
        isWheeling = false
        moves = []
        return [Report(.ended, speed: speed ?? read)]
    }

    /// The platform took the hand away.
    public mutating func cancelled() -> [Report] {
        guard open else { return [] }

        open = false
        isWheeling = false
        moves = []
        return [Report(.cancelled)]
    }

    /// A wheel's notch moved what is under the hand by `moved`, at `time`: the first opens a gesture, and steps
    /// slowing `fade` times in a row let it go - what follows of the momentum is swallowed until a gap in it, a
    /// step against it, or one pushing again.
    /// Design: docs/design/host/runtime.md#the-hand-over-a-layout
    public mutating func notched(_ moved: Point, at time: Double) -> [Report] {
        let size = (moved.x * moved.x + moved.y * moved.y).squareRoot()
        steps = steps.filter { time - $0.time < Self.window } + [(time, size)]
        let before = pace
        pace = steps.reduce(0) { $0 + $1.size } / Self.window
        let against = moved.x * heading.x + moved.y * heading.y < 0
        if size > 0 { heading = moved }

        if coasting {
            trough = min(trough, pace)
            let pushed = pace > trough * Self.surge && size >= Self.least
            guard time - last > Self.gap || against || pushed else {
                last = time
                return []
            }
            coasting = false
        }
        guard isWheeling else {
            let begun = began(at: time)
            isWheeling = true
            fading = 0
            return begun + self.moved(moved, at: time)
        }

        if size >= Self.least { fading = pace < before ? fading + 1 : pace > before ? 0 : fading }
        guard fading >= Self.fade else { return self.moved(moved, at: time) }

        let lift = lifted(at: time, speed: nil)
        coasting = true
        trough = pace
        last = time
        return lift
    }

    /// A frame at `time`: a wheel standing still for `pause` is let go, with no throw; a press standing still `hold`
    /// holds the view under it, where the layout's views are taken so; a held view is told again each `hold` it
    /// stands still.
    /// Design: docs/design/host/runtime.md#the-hand-over-a-layout
    public mutating func paced(at time: Double) -> [Report] {
        if let press, claimed == nil, itemStart == .held, time - press.time >= Self.hold {
            return itemTaken(at: press.point, time: time, now: time)
        }
        if holdsItem, time - itemMovedAt >= Double(stood + 1) * Self.hold {
            stood += 1
            return [Report(.changed, item: true, at: itemAt, still: time - itemMovedAt)]
        }
        guard isWheeling, time - last >= Self.pause else { return [] }

        return lifted(at: time, speed: .zero)
    }
}
