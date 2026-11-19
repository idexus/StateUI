// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What an element running a layout program shows of the program's answers: each child where the layout puts it,
/// shifted by its body - set out at a change of the layout, carried by a place that moves, stepped on the display's
/// frames - or exactly where the hand holds it.
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

    /// Whether a child is still on its way to its place.
    var moves: Bool { !bodies.isEmpty }

    /// Takes `answer` at `now` and says where each child is shown, in the children's order. A child is the body it
    /// says itself, else `layoutBodies`, its layout's for every child. A change the element has not set out yet sets each
    /// child it names out from where it was shown - one never shown, from nothing - at the speed it had, or the
    /// hand's; a child following its place is carried by its place's move; less motion, and a child of no body,
    /// stand at their places.
    mutating func take(
        _ answer: HostLayoutAnswer, layoutBodies: LayoutBody = .onChange(), at now: Double, reducesMotion: Bool
    ) -> [HostPlacement] {
        // The first answer shows the layout as it stands: nothing was shown for a change to set out from.
        let sets = applied != nil && applied != answer.change
        applied = answer.change

        var bodied = Set<Int>()
        for view in answer.views {
            guard let body = (view.body ?? layoutBodies).host, !reducesMotion else { continue }

            bodied.insert(view.key)
            var last = stood[view.key]?.target
            if sets, let discrete = view.discrete {
                let shift = stood[view.key].map { LayoutShift(from: $0.shown, to: discrete) } ?? .joining(discrete)
                let going = bodies[view.key]
                if shift != .none || going != nil {
                    var velocity = going?.velocity ?? LayoutShift.none.lanes
                    if let thrown = view.velocity {
                        velocity = LayoutShift.none.lanes
                        velocity[LayoutShift.x] = thrown.x
                        velocity[LayoutShift.y] = thrown.y
                    }
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
        return step(to: now)
    }

    /// Steps the bodies to `now` and says where each child of the answer last taken is shown.
    mutating func step(to now: Double) -> [HostPlacement] {
        bodies.step(to: now)

        var standing: [Int: Stood] = [:]
        standing.reserveCapacity(answer.views.count)
        let shown = answer.views.map { view -> HostPlacement in
            let placement = view.held
                ?? bodies[view.key].map { LayoutShift(lanes: $0.lanes).applied(to: view.target) }
                ?? view.target
            standing[view.key] = Stood(target: view.target, shown: placement)
            return placement
        }
        stood = standing
        return shown
    }
}
