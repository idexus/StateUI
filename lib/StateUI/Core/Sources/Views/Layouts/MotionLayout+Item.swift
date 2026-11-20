// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One view of a motion layout taken by the hand by itself: what the layout tells the application of it - the view
// held, what it is over, and the view thrown away. Where the view is drawn meanwhile is its host's.
// Design: docs/design/views/motion-layout.md#one-view-in-the-hand

extension MotionLayout.Run {
    /// The hand holding the view at `child` among the layout's views by itself, at `point` in the room, letting go
    /// at `velocity` points a second, having stood still `still` milliseconds: told as it takes the view, moves and
    /// stands, and lets it go - back, which is its host's, or dismissed.
    /// Design: docs/design/views/motion-layout.md#one-view-in-the-hand
    func item(_ gesture: GesturePhase, child: Int, at point: Point, velocity: Point, still: Double) {
        switch gesture {
        case .began:
            guard states.item.wrappedValue == nil, slots.indices.contains(child) else { return }

            let hand = LayoutItemHand(identity: slots[child].identity, from: point, at: point)
            states.item.wrappedValue = hand
            tell(hand, gesture, still: still, velocity: Point(x: 0, y: 0))

        case .changed:
            guard var hand = states.item.wrappedValue else { return }

            hand.at = point
            states.item.wrappedValue = hand
            tell(hand, gesture, still: still, velocity: velocity)

        case .ended, .cancelled:
            guard var hand = states.item.wrappedValue else { return }

            hand.at = point
            states.item.wrappedValue = nil
            tell(hand, gesture, still: 0, velocity: gesture == .ended ? velocity : Point(x: 0, y: 0))
        }
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
            phase: gesture, id: slot.item[keyPath: path], at: hand.at, room: Rect(x: 0, y: 0, width: room.width, height: room.height),
            still: .milliseconds(still), velocity: velocity, over: over)
        states.drags.starting(dragged.map { $0.given(drag) })()
    }

    /// Where each view rests by this description, at the parameters the run last showed: the arithmetic asked again, so
    /// an order the application changed a moment ago stands in it.
    private func places() -> [Int: Placement] {
        let memory = states.shown.wrappedValue
        guard let parameters = memory.parameters else { return memory.poses }

        let poses = pose(in: Rect(x: 0, y: 0, width: memory.room.width, height: memory.room.height), at: parameters, from: memory.from ?? parameters)
        return Dictionary(zip(slots.map(\.identity), poses), uniquingKeysWith: { first, _ in first })
    }

    /// The view at `child` among the layout's views was thrown away and has left the room: every `onItemDismissed`
    /// is told its item, each through its own gate, and this returns once every run they started has ended - what
    /// the host waits for before it puts a view nobody removed back.
    /// Design: docs/design/views/motion-layout.md#one-view-in-the-hand
    func dismissed(child: Int) async {
        guard slots.indices.contains(child) else { return }

        let id = slots[child].item[keyPath: path]
        for run in states.dismissals.started(dismissals.map { $0.given(id) }) { await run.value }
    }
}
