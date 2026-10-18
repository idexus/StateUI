// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A change of a layout's description at the current phase, travelling from where each view was shown.
// Design: docs/design/views/layout-engine.md#a-change-at-the-current-phase

extension LayoutEngine.Run {
    /// What the run last showed, a new description - or a new place its motion set out from - measured against it:
    /// worked out where the last frame stood, a view whose pose it changes sets out from where that frame showed it,
    /// and one joining from nothing; a change that changes nothing changes no way.
    /// Design: docs/design/views/layout-engine.md#a-change-at-the-current-phase
    func changed(at now: Double, from: Phase, reducesMotion: Bool) -> LayoutShown<Phase> {
        let motion = law.resolved(against: .standard)
        var memory = states.shown.wrappedValue
        guard memory.description != description || memory.from != from, let last = memory.phase, !reducesMotion,
              !motion.isNothing
        else { return memory }

        let room = Rect(0, 0, memory.room.width, memory.room.height)
        let before = pose(in: room, at: last, from: from)
        for (index, slot) in slots.enumerated() where memory.poses[slot.identity] != before[index] {
            let going = memory.travels[slot.identity].map { $0.at(now, under: motion) }
            let shift = memory.shown[slot.identity].map { LayoutShift(from: $0, to: before[index]) }
                ?? .joining(before[index])
            memory.travels[slot.identity] = shift == .none && going == nil ? nil : LayoutTravel(
                from: shift.lanes, velocity: going?.velocity ?? LayoutShift.none.lanes, began: now)
        }
        return memory
    }

    /// Shows `poses` - worked out at `phase` in `room` - each shifted by the change on its way to it in `memory`,
    /// and keeps what it showed for the next description to be measured against. Whether a change is still on its
    /// way.
    func show(
        _ poses: [Placement], after memory: LayoutShown<Phase>, at now: Double, phase: Phase, from: Phase, room: Rect,
        reducesMotion: Bool
    ) -> Bool {
        let identities = slots.map { $0.identity }
        let motion = law.resolved(against: .standard)
        let still = reducesMotion || motion.isNothing

        var shown = poses
        var travels: [String: LayoutTravel] = [:]
        for (index, identity) in identities.enumerated() where !still {
            guard let travel = memory.travels[identity] else { continue }

            let sample = travel.at(now, under: motion)
            guard !sample.rested else { continue }

            shown[index] = LayoutShift(lanes: sample.value).applied(to: poses[index])
            travels[identity] = travel
        }

        let holding = showHeld(&shown, travels: &travels, poses: poses, at: now, room: room)

        func byIdentity(_ run: [Placement]) -> [String: Placement] {
            Dictionary(zip(identities, run), uniquingKeysWith: { first, _ in first })
        }
        states.shown.wrappedValue = LayoutShown(
            description: description, phase: phase, from: from, room: room, poses: byIdentity(poses),
            shown: byIdentity(shown), travels: travels)
        states.placements.wrappedValue = PlacedRun(shown)
        return !travels.isEmpty || holding
    }
}
