// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A change of a layout's description at the current phase, traveling from where each view was shown.
// Design: docs/design/views/phase-layout.md#a-change-at-the-current-phase

extension PhaseLayout.Run {
    /// What the run last showed, a new description - or a new place its motion set out from - measured against it:
    /// worked out where the last frame stood, a view whose pose it changes sets out as a body from where that frame
    /// showed it, as fast as it went, and one joining from nothing; a change that changes nothing changes no way.
    /// Design: docs/design/views/phase-layout.md#a-change-at-the-current-phase
    func changed(at now: Double, from: Phase, reducesMotion: Bool) -> LayoutShown<Phase> {
        var memory = states.shown.wrappedValue
        guard memory.description != description || memory.from != from, let last = memory.phase, !reducesMotion,
              world.spring != nil
        else { return memory }

        let room = Rect(0, 0, memory.room.width, memory.room.height)
        let before = pose(in: room, at: last, from: from)
        for (index, slot) in slots.enumerated() where memory.poses[slot.identity] != before[index] {
            let going = memory.bodies[slot.identity]
            let shift = memory.shown[slot.identity].map { LayoutShift(from: $0, to: before[index]) }
                ?? .joining(before[index])
            guard shift != .none || going != nil else { continue }

            memory.bodies.set(
                slot.identity, lanes: shift.lanes, velocity: going?.velocity ?? LayoutShift.none.lanes,
                spring: spring(of: index), at: now)
        }
        // The poses as this description stands them where the last frame stood: a body following its place is carried
        // by the phase's move alone.
        memory.poses = Dictionary(zip(slots.map(\.identity), before), uniquingKeysWith: { first, _ in first })
        return memory
    }

    /// The spring the view at `index` comes onto its place on: its own body's, else the world's.
    func spring(of index: Int) -> LayoutBodies.Spring {
        body(index)?.spring ?? world.spring ?? LayoutBodies.Spring(response: 300, damping: 1)
    }

    /// Shows `poses` - worked out at `phase` in `room` - each shifted by its body in the world `memory` holds, a body
    /// following its place carried by its place's move since the last frame and the world worked out to `now`, and
    /// keeps what it showed for the next description to be measured against. Whether a body is still on its way.
    /// Design: docs/design/views/phase-layout.md#bodies
    func show(
        _ poses: [Placement], after memory: LayoutShown<Phase>, at now: Double, phase: Phase, from: Phase, room: Rect,
        reducesMotion: Bool
    ) -> Bool {
        let identities = slots.map { $0.identity }
        var bodies = memory.bodies
        if reducesMotion || world.spring == nil {
            bodies = LayoutBodies()
        } else {
            bodies.keep(only: Set(identities))
            for (index, identity) in identities.enumerated() {
                guard let follower = body(index), let last = memory.poses[identity], last != poses[index] else { continue }
                bodies.carry(identity, by: LayoutShift(from: last, to: poses[index]).lanes, spring: follower.spring, at: now)
            }
            bodies.step(to: now)
        }

        var shown = poses
        for (index, identity) in identities.enumerated() {
            guard let body = bodies[identity] else { continue }
            shown[index] = LayoutShift(lanes: body.lanes).applied(to: poses[index])
        }

        let holding = showHeld(&shown, bodies: &bodies, poses: poses, at: now, room: room)

        func byIdentity(_ run: [Placement]) -> [Int: Placement] {
            Dictionary(zip(identities, run), uniquingKeysWith: { first, _ in first })
        }
        states.shown.wrappedValue = LayoutShown(
            description: description, phase: phase, from: from, room: room, poses: byIdentity(poses),
            shown: byIdentity(shown), bodies: bodies, resting: memory.resting)
        states.placements.wrappedValue = PlacedRun(shown)
        return !bodies.isEmpty || holding
    }
}
