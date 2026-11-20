// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A change of a layout's description at the current parameters, traveling from where each view was shown.
// Design: docs/design/views/motion-layout.md#a-change-where-the-parameters-stand

extension MotionLayout.Run {
    /// What the run last answered, a new description - or a new place its motion set out from - measured against
    /// it: worked out where the last frame stood, a view whose pose it changes is answered that pose as the place
    /// its way is measured to (`HostLayoutView.discrete`); a change that changes nothing changes no way.
    /// Design: docs/design/views/motion-layout.md#a-change-where-the-parameters-stand
    func changed(from: Parameters) -> (memory: LayoutShown<Parameters>, discrete: [Int: Placement]) {
        var memory = states.shown.wrappedValue
        guard memory.description != description || memory.from != from, let last = memory.parameters
        else { return (memory, [:]) }

        let room = Rect(x: 0, y: 0, width: memory.room.width, height: memory.room.height)
        let before = pose(in: room, at: last, from: from)
        var discrete: [Int: Placement] = [:]
        for (index, slot) in slots.enumerated() where memory.poses[slot.identity] != before[index] {
            discrete[slot.identity] = before[index]
        }
        // The poses as this description stands them where the last frame stood.
        memory.poses = Dictionary(zip(slots.map(\.identity), before), uniquingKeysWith: { first, _ in first })
        return (memory, discrete)
    }

    /// Answers the host `poses` - worked out at `parameters` in `room` - each with its body, the places a change
    /// measures its views' ways to, and the view the hand holds where it holds it; and keeps what it answered for
    /// the next description to be measured against. Whether the hand's own movement goes on.
    /// Design: docs/design/views/motion-layout.md#bodies
    func show(
        _ poses: [Placement], after memory: LayoutShown<Parameters>, discrete: [Int: Placement], at now: Double,
        parameters: Parameters, from: Parameters, room: Rect
    ) -> Bool {
        let identities = slots.map { $0.identity }
        var poses = poses
        let hand = hold(over: &poses, at: now, room: room)
        if !discrete.isEmpty { states.slot.changed(discrete) }

        var placed = poses
        var views: [HostLayoutView] = []
        views.reserveCapacity(poses.count)
        for (index, identity) in identities.enumerated() {
            var view = HostLayoutView(
                key: identity, target: HostBoundary.placement(of: poses[index]), body: body(index))
            view.discrete = states.slot.discrete[identity].map(HostBoundary.placement(of:))
            if let held = hand.held, held.index == index {
                view.held = HostBoundary.placement(of: held.placement)
                placed[index] = held.placement
            }
            views.append(view)
        }

        states.shown.wrappedValue = LayoutShown(
            description: description, parameters: parameters, from: from, room: room,
            poses: Dictionary(zip(identities, poses), uniquingKeysWith: { first, _ in first }),
            named: states.shown.wrappedValue.named, resting: memory.resting)
        states.slot.answer = HostLayoutAnswer(views: views, change: states.slot.changes)
        states.slot.placed = PlacedRun(placed)
        return hand.goesOn
    }
}
