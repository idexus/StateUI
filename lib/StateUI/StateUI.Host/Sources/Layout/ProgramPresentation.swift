// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What an element running a layout program shows of the program's answers: each child where the layout puts it -
/// moved by what its own press answers - shifted by its body - set out at a change of the layout, carried by a
/// place that moves, stepped on the display's frames - or exactly where the hand holds it.
/// Design: docs/design/host/layout.md#bodies
struct ProgramPresentation {
    /// Where a child's layout last put it, and where the element showed it.
    private struct Stood {
        var target: HostPlacement
        var shown: HostPlacement
    }

    /// The answer shown, which a frame with no new one steps again.
    private var answer = HostLayoutAnswer()

    /// The change of the layout last set out; nil before any answer was taken.
    private var applied: UInt64?

    /// Where each child stood at the last answer or frame, by its key.
    private var stood: [Int: Stood] = [:]

    private var bodies = LayoutBodies()

    /// What decides a child's body, and whether the user asked for less motion, as the last answer was taken.
    private var layoutBodies = LayoutBody.onChange()
    private var reducesMotion = false

    /// The offset each child's press last moved its place by, and each child a hand holds by itself as it was
    /// shown when the hand took it, by key.
    /// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
    private var offsets: [Int: PresentationOffset] = [:]
    private var taken: [Int: HostPlacement] = [:]

    /// Whether a child is still on its way to its place.
    var moves: Bool { !bodies.isEmpty }

    /// Takes `answer` at `now` and says where each child is shown, in the children's order. A child is the body it
    /// says itself, else `layoutBodies`, its layout's for every child. A change the element has not set out yet sets each
    /// child it names out from where it was shown - one never shown, from nothing - at the speed it had, or the
    /// hand's; a child following its place is carried by its place's move; less motion, and a child of no body,
    /// stand at their places.
    mutating func take(
        _ answer: HostLayoutAnswer, layoutBodies: LayoutBody = .onChange(), locals: [LocalPresentation] = [],
        at now: Double, reducesMotion: Bool
    ) -> [HostPlacement] {
        // The first answer shows the layout as it stands: nothing was shown for a change to set out from.
        let sets = applied != nil && applied != answer.change
        applied = answer.change
        self.layoutBodies = layoutBodies
        self.reducesMotion = reducesMotion

        var bodied = Set<Int>()
        for view in answer.views {
            guard let body = (view.body ?? layoutBodies).host, !reducesMotion else { continue }

            bodied.insert(view.key)
            var last = stood[view.key]?.target
            if sets, let discrete = view.discrete {
                let shift = stood[view.key].map { LayoutShift(from: $0.shown, to: discrete) } ?? .joining(discrete)
                let going = bodies[view.key]
                if shift != .none || going != nil {
                    let velocity = going?.velocity ?? LayoutShift.none.lanes
                    bodies.set(view.key, lanes: shift.lanes, velocity: velocity, spring: body, at: now)
                }
                last = discrete
            }
            if body.follows, let last, last != view.target {
                bodies.carry(view.key, by: LayoutShift(from: last, to: view.target).lanes, spring: body, at: now)
            }
        }
        bodies.keep(only: bodied)
        self.answer = answer
        return step(to: now, locals: locals)
    }

    /// Where the child at `index` of the answer is shown and where its layout puts it, while the two differ.
    func travel(at index: Int) -> (standing: Rect, destination: Rect)? {
        guard answer.views.indices.contains(index), let child = stood[answer.views[index].key],
              child.shown.bounds != child.target.bounds
        else { return nil }
        return (child.shown.bounds, child.target.bounds)
    }

    /// Steps the bodies to `now` and says where each child of the answer last taken is shown, the children's own
    /// presses and holds - `locals`, in the children's order - laid over the layout's places.
    mutating func step(to now: Double, locals: [LocalPresentation] = []) -> [HostPlacement] {
        func local(at index: Int) -> LocalPresentation {
            locals.indices.contains(index) ? locals[index] : LocalPresentation()
        }
        func body(of view: HostLayoutView) -> HostLayoutBody? {
            reducesMotion ? nil : (view.body ?? layoutBodies).host
        }
        // A press moves its view's place: a body following its layout is carried by that move as by any other.
        for (index, view) in answer.views.enumerated() {
            let (offset, before) = (local(at: index).pressed, offsets[view.key] ?? .identity)
            guard offset != before else { continue }

            offsets[view.key] = offset == .identity ? nil : offset
            if let body = body(of: view), body.follows {
                let moved = LayoutShift(from: before.applied(to: view.target), to: offset.applied(to: view.target))
                bodies.carry(view.key, by: moved.lanes, spring: body, at: now)
            }
        }
        // A view the hand let go sets out from where it was shown, at the hand's speed - one of no body is at
        // its place at once.
        for (index, view) in answer.views.enumerated() where taken[view.key] != nil && local(at: index).held == nil {
            taken[view.key] = nil
            guard let body = body(of: view), let shown = stood[view.key]?.shown else { continue }

            var velocity = LayoutShift.none.lanes
            velocity[LayoutShift.x] = local(at: index).letGo.x
            velocity[LayoutShift.y] = local(at: index).letGo.y
            let from = LayoutShift(from: shown, to: local(at: index).pressed.applied(to: view.target))
            bodies.set(view.key, lanes: from.lanes, velocity: velocity, spring: body, at: now)
        }
        bodies.step(to: now)

        var standing: [Int: Stood] = [:]
        standing.reserveCapacity(answer.views.count)
        var held: [Int] = []
        var shown = answer.views.enumerated().map { index, view -> HostPlacement in
            let target = local(at: index).pressed.applied(to: view.target)
            var placement = bodies[view.key].map { LayoutShift(lanes: $0.lanes).applied(to: target) } ?? target
            if let moved = local(at: index).held {
                // Taken as it was last shown, and pinned to the hand from there whatever its place does meanwhile.
                let from = taken[view.key] ?? stood[view.key]?.shown ?? target
                taken[view.key] = from
                placement = target.pinned(to: from, moved: moved)
                held.append(index)
            }
            standing[view.key] = Stood(target: view.target, shown: placement)
            return placement
        }
        taken = taken.filter { standing[$0.key] != nil }
        Self.raise(held, in: &shown)
        stood = standing
        return shown
    }

    /// Ranks the views at `held` over every other of `shown`: one above the highest - the others ranked anew, in
    /// their order, where that is the highest an integer holds.
    private static func raise(_ held: [Int], in shown: inout [HostPlacement]) {
        guard !held.isEmpty else { return }

        let others = shown.indices.filter { !held.contains($0) }
        var top = others.map { shown[$0].zIndex }.max() ?? 0
        if top > .max - held.count {
            let ordered = others.sorted { shown[$0].zIndex != shown[$1].zIndex ? shown[$0].zIndex < shown[$1].zIndex : $0 < $1 }
            for (rank, index) in ordered.enumerated() { shown[index] = shown[index].ranked(rank) }
            top = ordered.count - 1
        }
        for (place, index) in held.enumerated() { shown[index] = shown[index].ranked(top + 1 + place) }
    }
}
