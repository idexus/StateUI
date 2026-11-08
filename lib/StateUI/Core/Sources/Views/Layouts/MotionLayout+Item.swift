// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One view of a motion layout taken by the hand by itself: found under the press, kept to the hand over the others,
// let go back to its place under the layout's motion or, past a dismissal, flown on out of the room.
// Design: docs/design/views/motion-layout.md#one-view-in-the-hand

/// Which ways letting a view go dismisses it, how far the hand must take it first, and what is told of its item.
struct LayoutDismissal<Item> {
    let directions: SwipeDirections
    let threshold: Double
    let handler: ValueHandler<Item>
}

extension MotionLayout.Run {
    /// The hand holding one view by itself at the parameters, at `point` in the room, letting go at `velocity` points a
    /// second, having stood still `still` milliseconds: taken where it presses, told as it moves and stands, let go
    /// back or dismissed.
    /// Design: docs/design/views/motion-layout.md#one-view-in-the-hand
    func item(_ gesture: GesturePhase, at point: Point, velocity: Point, still: Double) {
        switch gesture {
        case .began:
            guard states.item.wrappedValue?.velocity != nil || states.item.wrappedValue == nil,
                  let (identity, placement) = view(at: point)
            else { return }

            let hand = LayoutItemHand(identity: identity, taken: placement, from: point, at: point)
            states.item.wrappedValue = hand
            tell(hand, gesture, still: still, velocity: Point(x: 0, y: 0))

        case .changed:
            guard var hand = states.item.wrappedValue, hand.velocity == nil else { return }

            hand.at = point
            states.item.wrappedValue = hand
            tell(hand, gesture, still: still, velocity: velocity)

        case .ended, .cancelled:
            guard var hand = states.item.wrappedValue, hand.velocity == nil else { return }

            hand.at = point
            hand.velocity = gesture == .ended ? velocity : Point(x: 0, y: 0)
            hand.dismissed = gesture == .ended && dismisses(hand)
            states.item.wrappedValue = hand
            tell(hand, gesture, still: 0, velocity: hand.velocity ?? Point(x: 0, y: 0))
        }
    }

    /// The view drawn on top at `point` in the room, by what the run last showed - its place turned as it is drawn,
    /// a view drawn clear passed over - and that place.
    func view(at point: Point) -> (Int, Placement)? {
        view(at: point, among: states.shown.wrappedValue.shown)
    }

    /// The view on top at `point` among `placements`, by identity - a view drawn clear and the view of `passing`
    /// passed over - and its placement there.
    private func view(at point: Point, among placements: [Int: Placement], passing: Int? = nil) -> (Int, Placement)? {
        let under = slots.enumerated().compactMap { index, slot -> (Int, Int, Placement)? in
            guard slot.identity != passing, let placement = placements[slot.identity], placement.opacity > 0,
                  Self.covers(placement, point)
            else { return nil }
            return (index, slot.identity, placement)
        }
        let top = under.max { one, other in
            one.2.zIndex != other.2.zIndex ? one.2.zIndex < other.2.zIndex : one.0 < other.0
        }
        return top.map { ($0.1, $0.2) }
    }

    /// Whether `placement`, turned as it is drawn about its middle, covers `point`.
    static func covers(_ placement: Placement, _ point: Point) -> Bool {
        let bounds = placement.bounds
        guard let undo = placement.transform.drawn.inverted else { return false }

        let x = point.x - (bounds.x + bounds.width / 2)
        let y = point.y - (bounds.y + bounds.height / 2)
        let along = undo.a * x + undo.c * y + undo.tx
        let down = undo.b * x + undo.d * y + undo.ty
        return abs(along) <= bounds.width / 2 && abs(down) <= bounds.height / 2
    }

    /// Tells the application the view `hand` holds at the parameters, having stood still `still` milliseconds, the hand
    /// going at `speed` - and the item whose place stands under it: where a view rests, not where it is drawn on its
    /// way, so a view traveling off from under the hand after it made room answers no second time.
    /// Design: docs/design/views/motion-layout.md#one-view-in-the-hand
    func tell(_ hand: LayoutItemHand, _ gesture: GesturePhase, still: Double, velocity: Point) {
        guard !dragged.isEmpty, let slot = slots.first(where: { $0.identity == hand.identity }) else { return }

        let room = states.room.wrappedValue
        let over = view(at: hand.at, among: places(), passing: hand.identity).flatMap { under in
            slots.first { $0.identity == under.0 }?.item[keyPath: path]
        }
        let drag = ItemDrag(
            phase: gesture, id: slot.item[keyPath: path], at: hand.at, room: Rect(0, 0, room.width, room.height),
            still: .milliseconds(still), velocity: velocity, over: over)
        states.drags.starting(dragged.map { $0.given(drag) })()
    }

    /// Where each view rests by this description, at the parameters the run last showed: the arithmetic asked again, so
    /// an order the application changed a moment ago stands in it.
    private func places() -> [Int: Placement] {
        let memory = states.shown.wrappedValue
        guard let parameters = memory.parameters else { return memory.poses }

        let poses = pose(in: Rect(0, 0, memory.room.width, memory.room.height), at: parameters, from: memory.from ?? parameters)
        return Dictionary(zip(slots.map(\.identity), poses), uniquingKeysWith: { first, _ in first })
    }

    /// Whether letting `hand` go dismisses its view: it passes one of the dismissals.
    func dismisses(_ hand: LayoutItemHand) -> Bool {
        !passed(by: hand).isEmpty
    }

    /// The places, in the order written, of the dismissals `hand`'s view passes: where the hand took it, and where
    /// a throw at its speed would carry it, stands past the dismissal one of its ways.
    private func passed(by hand: LayoutItemHand) -> Set<Int> {
        guard let velocity = hand.velocity else { return [] }

        let across = hand.at.x - hand.from.x + Self.carried(velocity.x, by: throwing)
        let down = hand.at.y - hand.from.y + Self.carried(velocity.y, by: throwing)
        let ways: [(SwipeDirection, Double)] = [(.up, -down), (.down, down), (.left, -across), (.right, across)]
        return Set(dismissals.indices.filter { place in
            ways.contains { dismissals[place].directions.contains($0.0) && $0.1 > dismissals[place].threshold }
        })
    }

    /// The held view in `shown`, as the hand holds it - `poses` worked out at `now` in `room` - and the bodies of
    /// the world in `bodies`: let go, it goes back onto its place as a body, setting out at the hand's speed;
    /// dismissed, it flies on, and its item is told once it has left the room. Whether it goes on.
    func showHeld(
        _ shown: inout [Placement], bodies: inout LayoutBodies, poses: [Placement], at now: Double, room: Rect
    ) -> Bool {
        guard var hand = states.item.wrappedValue else { return false }
        guard let index = slots.firstIndex(where: { $0.identity == hand.identity }) else {
            states.item.wrappedValue = nil
            return false
        }

        var placement = hand.held(shown[index], over: shown)
        if let thrown = hand.velocity, !hand.dismissed {
            let lanes = LayoutShift(from: placement, to: poses[index]).lanes
            var velocity = LayoutShift.none.lanes
            velocity[LayoutShift.x] = thrown.x
            velocity[LayoutShift.y] = thrown.y
            bodies.set(hand.identity, lanes: lanes, velocity: velocity, spring: spring(of: index), at: now)
            shown[index] = LayoutShift(lanes: lanes).applied(to: poses[index])
            states.item.wrappedValue = nil
            return true
        }
        if hand.dismissed {
            let flew = hand.flew ?? now
            let flying = flight(of: hand, in: room)
            placement.bounds.x += flying.x * (now - flew) / 1_000
            placement.bounds.y += flying.y * (now - flew) / 1_000
            hand.flew = flew
            if !hand.gone, Self.outside(placement, room) {
                hand.gone = true
                dismissed(hand)
            }
            if hand != states.item.wrappedValue { states.item.wrappedValue = hand }
        }
        shown[index] = placement
        return hand.dismissed && !hand.gone
    }

    /// How fast a dismissed view flies on, per second: the hand's speed, and its way out no slower than the room's
    /// length a response of the world's spring.
    func flight(of hand: LayoutItemHand, in room: Rect) -> Point {
        var velocity = hand.velocity ?? Point(x: 0, y: 0)
        let length = max(world.spring?.response ?? 0, 1) / 1_000
        let across = hand.at.x - hand.from.x, down = hand.at.y - hand.from.y
        if abs(down) >= abs(across) {
            velocity.y = down < 0 ? min(velocity.y, -room.height / length) : max(velocity.y, room.height / length)
        } else {
            velocity.x = across < 0 ? min(velocity.x, -room.width / length) : max(velocity.x, room.width / length)
        }
        return velocity
    }

    /// Whether `placement` stands wholly outside `room`.
    static func outside(_ placement: Placement, _ room: Rect) -> Bool {
        let bounds = placement.bounds
        return bounds.x + bounds.width <= 0 || bounds.y + bounds.height <= 0
            || bounds.x >= room.width || bounds.y >= room.height
    }

    /// Tells the application, through every dismissal `hand`'s view passed - each through its own gate - that its
    /// item has been dismissed, after the frame.
    func dismissed(_ hand: LayoutItemHand) {
        let passed = passed(by: hand)
        guard !passed.isEmpty, let slot = slots.first(where: { $0.identity == hand.identity }) else { return }

        let id = slot.item[keyPath: path]
        let start = states.dismissals.starting(dismissals.map { $0.handler.given(id) }) { passed.contains($0) }
        libraryTask { start() }
    }
}
