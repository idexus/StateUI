// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One view of a phase layout taken by the hand by itself: found under the press, kept to the hand over the others,
// let go back to its place under the layout's motion or, past a dismissal, flown on out of the room.
// Design: docs/design/views/phase-layout.md#one-view-in-the-hand

/// Which ways letting a view go dismisses it, how far the hand must take it first, and what is told of its item.
struct LayoutDismissal<Item> {
    let directions: SwipeDirection
    let beyond: Double
    let handler: ValueHandler<Item>
}

extension PhaseLayout.Run {
    /// The hand holding one view by itself at `phase`, at `point` in the room, letting go at `speed` points a second,
    /// having stood still `still` milliseconds: taken where it presses, told as it moves and stands, let go back or
    /// dismissed.
    /// Design: docs/design/views/phase-layout.md#one-view-in-the-hand
    func item(_ phase: GesturePhase, at point: Point, speed: Point, still: Double) throws {
        switch phase {
        case .began:
            guard states.item.wrappedValue?.speed != nil || states.item.wrappedValue == nil,
                  let (identity, placement) = view(at: point)
            else { return }

            let hand = LayoutItemHand(identity: identity, taken: placement, from: point, at: point)
            states.item.wrappedValue = hand
            try tell(hand, phase, still: still)

        case .changed:
            guard var hand = states.item.wrappedValue, hand.speed == nil else { return }

            hand.at = point
            states.item.wrappedValue = hand
            try tell(hand, phase, still: still)

        case .ended, .cancelled:
            guard var hand = states.item.wrappedValue, hand.speed == nil else { return }

            hand.at = point
            hand.speed = phase == .ended ? speed : Point(x: 0, y: 0)
            hand.dismissed = phase == .ended && dismisses(hand)
            states.item.wrappedValue = hand
            try tell(hand, phase, still: 0)
        }
    }

    /// The view drawn on top at `point` in the room, by what the run last showed - its place turned as it is drawn,
    /// a view drawn clear passed over - and that place.
    func view(at point: Point) -> (Int, Placement)? {
        let shown = states.shown.wrappedValue.shown
        let under = slots.enumerated().compactMap { index, slot -> (Int, Int, Placement)? in
            guard let placement = shown[slot.identity], placement.opacity > 0, Self.covers(placement, point)
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
        guard let undo = placement.transform.inverted else { return false }

        let x = point.x - (bounds.x + bounds.width / 2)
        let y = point.y - (bounds.y + bounds.height / 2)
        let along = undo.a * x + undo.c * y + undo.tx
        let down = undo.b * x + undo.d * y + undo.ty
        return abs(along) <= bounds.width / 2 && abs(down) <= bounds.height / 2
    }

    /// Tells the application the view `hand` holds at `phase`, having stood still `still` milliseconds.
    func tell(_ hand: LayoutItemHand, _ phase: GesturePhase, still: Double) throws {
        guard let dragged, let slot = slots.first(where: { $0.identity == hand.identity }) else { return }

        let room = states.room.wrappedValue
        try dragged(ItemDrag(
            phase: phase, item: slot.item, at: hand.at, room: Rect(0, 0, room.width, room.height),
            still: .milliseconds(still)))
    }

    /// Whether letting `hand` go dismisses its view: where the hand took it, and where a throw at its speed would
    /// carry it, stands past the dismissal one of its ways.
    func dismisses(_ hand: LayoutItemHand) -> Bool {
        guard let dismissal, let speed = hand.speed else { return false }

        let across = hand.at.x - hand.from.x + Self.carried(speed.x, by: throwing)
        let down = hand.at.y - hand.from.y + Self.carried(speed.y, by: throwing)
        let ways: [(SwipeDirection, Double)] = [(.up, -down), (.down, down), (.left, -across), (.right, across)]
        return ways.contains { dismissal.directions.contains($0.0) && $0.1 > dismissal.beyond }
    }

    /// The held view in `shown`, as the hand holds it - `poses` worked out at `now` in `room` - and the changes on
    /// their way in `travels`: let go, its way back is a change under the layout's motion, setting out at the hand's
    /// speed; dismissed, it flies on, and its item is told once it has left the room. Whether it goes on.
    func showHeld(
        _ shown: inout [Placement], travels: inout [Int: LayoutTravel], poses: [Placement], at now: Double,
        room: Rect
    ) -> Bool {
        guard var hand = states.item.wrappedValue else { return false }
        guard let index = slots.firstIndex(where: { $0.identity == hand.identity }) else {
            states.item.wrappedValue = nil
            return false
        }

        var placement = hand.held(shown[index], over: shown)
        if let speed = hand.speed, !hand.dismissed {
            let lanes = LayoutShift(from: placement, to: poses[index]).lanes
            var velocity = LayoutShift.none.lanes
            velocity[LayoutShift.x] = speed.x
            velocity[LayoutShift.y] = speed.y
            travels[hand.identity] = LayoutTravel(from: lanes, velocity: velocity, began: now)
            shown[index] = LayoutShift(lanes: lanes).applied(to: poses[index])
            states.item.wrappedValue = nil
            return true
        }
        if hand.dismissed {
            let flew = hand.flew ?? now
            let speed = flight(of: hand, in: room)
            placement.bounds.x += speed.x * (now - flew) / 1_000
            placement.bounds.y += speed.y * (now - flew) / 1_000
            hand.flew = flew
            if !hand.gone, Self.outside(placement, room) {
                hand.gone = true
                dismissed(hand.identity)
            }
            if hand != states.item.wrappedValue { states.item.wrappedValue = hand }
        }
        shown[index] = placement
        return hand.dismissed && !hand.gone
    }

    /// How fast a dismissed view flies on, per second: the hand's speed, and its way out no slower than the room's
    /// length a length of the layout's motion.
    func flight(of hand: LayoutItemHand, in room: Rect) -> Point {
        var speed = hand.speed ?? Point(x: 0, y: 0)
        let length = max(Double(resolvedLaw.milliseconds), 1) / 1_000
        let across = hand.at.x - hand.from.x, down = hand.at.y - hand.from.y
        if abs(down) >= abs(across) {
            speed.y = down < 0 ? min(speed.y, -room.height / length) : max(speed.y, room.height / length)
        } else {
            speed.x = across < 0 ? min(speed.x, -room.width / length) : max(speed.x, room.width / length)
        }
        return speed
    }

    /// Whether `placement` stands wholly outside `room`.
    static func outside(_ placement: Placement, _ room: Rect) -> Bool {
        let bounds = placement.bounds
        return bounds.x + bounds.width <= 0 || bounds.y + bounds.height <= 0
            || bounds.x >= room.width || bounds.y >= room.height
    }

    /// Tells the application the item whose view `identity` shows has been dismissed, after the frame.
    func dismissed(_ identity: Int) {
        guard let dismissal, let slot = slots.first(where: { $0.identity == identity }) else { return }

        let (handler, item, runs) = (dismissal.handler, slot.item, states.dismissals)
        libraryTask {
            handler.gate.runs(for: runs).start(
                { try await handler.run(item) }, handler.gate.policy, payload: nil, owner: runs)
        }
    }
}
