// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A motion layout on a bench: rendered, told its room as the host tells it, and turned frame by frame on a display
/// clock of its own, so two turns in one test are two instants.
@MainActor
final class LayoutBench {
    /// Where the display clock stands.
    private var turned = 0.0

    /// The number of the phase the layout last laid out wears on the host's channel.
    private var worn: Int32?

    /// Whether each cycle walks that phase as a host's animator does (`walk`); a test saying itself what the host
    /// reports leaves it off.
    var walks = false

    /// One cycle of the display's board - with less motion asked for, where `reducesMotion` - the host walking the
    /// laid layout's phase first, where the bench `walks`.
    func cycle(reducesMotion: Bool = false) {
        let before = turned
        turned += 16
        if walks, let worn { walk(worn, setOut: before) }
        _ = Renderer.shared.board.cycle(now: turned, reducesMotion: reducesMotion)
        ask()
    }

    /// Where the parameters stood when the bench last asked the program.
    private var asked: [Double]?

    /// Asks the program where its views stand, as a host does in its own frame: where the cycle said the layout is
    /// to be asked again - its room, its description, a state its arithmetic follows - or the parameters' sample
    /// moved. A frame that moved nothing asks nothing.
    private func ask() {
        guard let program else { return }

        let stirred = Renderer.shared.board.stirred.contains(program.slot)
        Renderer.shared.board.stirred.removeAll { $0 == program.slot }
        // Where the parameters stand: what the bench walked, or - a test saying itself what the host reports -
        // what the channel stands at.
        let sample = worn.flatMap { HostAnimatorReport.standing($0)?.1.value } ?? reported?.value
        guard stirred || sample != asked else { return }

        asked = sample
        _ = program.answered()
    }

    /// The program of the layout last laid or shown, which a patch names only when its description made another.
    private(set) var program: HostLayoutProgram?

    /// Where the layout of `patch` shows its views, in the items' order, as the host reads the run.
    func shown(_ patch: HostPatch) -> [Placement] {
        takes(patch)
        return placed
    }

    /// The program `patch` hands the host, which the bench asks from then on as the host does; nil where the
    /// patch describes no layout anew.
    @discardableResult
    func takes(_ patch: HostPatch) -> HostLayoutProgram? {
        guard let described = patch.first(.motionLayout)?.program else { return nil }

        program = described
        return described
    }

    /// Where the layout last laid or shown puts its views now - a view the hand holds where it holds it - no tree
    /// described again. Bringing a view onto its place is the host's: the bench shows where it goes.
    var placed: [Placement] { program?.run?().placements ?? [] }

    /// What the layout last answered its host: each view's place, its body, and where a change measures its way to.
    var answer: HostLayoutAnswer { program?.answered() ?? HostLayoutAnswer() }


    /// Says the layout its room, as the host does when its toolkit lays it out anew.
    func room(_ width: Double, _ height: Double) {
        program?.layOut(width, height)
    }

    /// The journey of the phase the host walks, as it set out, and when: what `walk` samples its law from; and what
    /// the walk last reported, so a write since is told from it.
    private var walk: (from: HostJourney, began: Double)?
    private var reported: (value: [Double], velocity: [Double])?

    /// The phase `worn` as a host's animator walks it this frame: its journey, where it set out anew - another
    /// destination or law than the walk under way, a value or a speed written since - walked from there under its
    /// law, set out at `setOut`; where its law puts it reported back, and the walk over once it rests.
    private func walk(_ worn: Int32, setOut: Double) {
        // What the board wrote since, read as a host reads it: a report speaks of the journey it last read.
        guard let (binding, standing) = HostAnimatorReport.standing(worn) else { return }

        let anew = walk.map { $0.from.destination != standing.destination || $0.from.motion != standing.motion } ?? true
        let written = reported.map { $0.value != standing.value || $0.velocity != standing.velocity } ?? true
        if anew || written {
            let still = standing.value == standing.destination && standing.velocity.allSatisfy { $0 == 0 }
            walk = still ? nil : (standing, setOut)
        }
        guard let (from, began) = walk else {
            // A channel says where it stands as it opens: its first sample.
            if reported == nil {
                XCTAssertTrue(HostBoundary.report(standing, updating: .frame, through: binding, at: turned), "refused")
            }
            return reported = (standing.value, standing.velocity)
        }

        let law = from.motion.resolved(against: StandardEnvironment.application.motion)
        let sample = HostMotionLaw.sample(
            law, elapsed: turned - began, from: from.value, destination: from.destination, velocity: from.velocity)
        let journey = HostJourney(
            value: sample.value, destination: from.destination, velocity: sample.velocity, motion: from.motion,
            completion: standing.completion, stopped: standing.stopped)
        XCTAssertTrue(
            HostBoundary.report(journey, updating: [.value, .velocity], through: binding, at: turned), "the walk refused")
        reported = (sample.value, sample.velocity)
        if sample.rested { walk = nil }
    }

    /// One frame as the host runs it: the board's cycle, and what it wrote read out, so a report after it lands.
    func frame() {
        turned += 16
        _ = HostBoundary.cycle(now: turned, reducesMotion: false)
    }

    /// The hand holding one view of the layout `tree` describes, as the host layer reports it - its phase, where it is
    /// in the room, its speed as it lets go, per second, and how long it has stood still - and a cycle after it.
    func item(
        _ renders: Renders, _ tree: () -> Node, _ phase: GesturePhase, at: Point, velocity: Point = .zero,
        still: Double = 0, file: StaticString = #filePath, line: UInt = #line
    ) {
        let patch = renders.renderFromScratch(tree())
        guard let heard = patch.first(.motionLayout)?.events?[.itemDragUpdated] else {
            return XCTFail("the layout hears no hand on its views", file: file, line: line)
        }
        // The host says which view the hand took: here, the one on top whose place the press stands in.
        if phase == .began {
            let places = shown(patch)
            taken = places.indices.filter { index in
                let bounds = places[index].bounds
                return at.x >= bounds.x && at.x <= bounds.x + bounds.width && at.y >= bounds.y
                    && at.y <= bounds.y + bounds.height
            }.max { places[$0].zIndex != places[$1].zIndex ? places[$0].zIndex < places[$1].zIndex : $0 < $1 } ?? 0
        }

        XCTAssertTrue(
            renders.fire(heard, with: MemberValues.encode(phase, at, velocity, still, taken)), file: file, line: line)
        cycle()
    }

    /// The view the hand took last, by its place among the layout's views.
    private var taken = 0

    /// The layout `tree` describes came to rest with its parameters at `lanes`, as its host says once nothing
    /// moves it - and a cycle after it. Whether the layout hears it.
    @discardableResult
    func rested(_ renders: Renders, _ tree: () -> Node, at lanes: [Double]) -> Bool {
        let patch = renders.renderFromScratch(tree())
        guard let heard = patch.first(.motionLayout)?.events?[.settled] else { return false }

        let fired = renders.fire(heard, with: MemberValues.encode(lanes))
        cycle()
        return fired
    }

    /// A view of the layout `tree` describes thrown away and out of the room, as the host layer says it once the
    /// view has left - its place among the layout's views, the way it went and the hand's speed - and a cycle
    /// after it; `ended` is said once every run the layout's handlers started has ended. Whether the layout
    /// hears it.
    @discardableResult
    func dismissed(
        _ renders: Renders, _ tree: () -> Node, child: Int, direction: SwipeDirection = .up, velocity: Point = .zero,
        ended: @escaping @MainActor () -> Void = {}
    ) -> Bool {
        let patch = renders.renderFromScratch(tree())
        guard let heard = patch.first(.motionLayout)?.events?[.itemDismissed] else { return false }

        let fired = renders.fire(Int(heard), with: MemberValues.encode(child, direction, velocity), ended: ended)
        cycle()
        return fired
    }

    /// Renders `tree`, feeds the layout the room `room` as the host does, and turns the board until the arithmetic
    /// has answered: the run of placements the layout's own area carries.
    func laid(
        _ renders: Renders, _ tree: () -> Node, room: Rect = Rect(x: 10, y: 20, width: 300, height: 200),
        file: StaticString = #filePath, line: UInt = #line
    ) -> (patch: HostPatch, run: [Placement]) {
        let patch = renders.render(tree())

        guard let layout = patch.first(.motionLayout), let described = layout.program else {
            XCTFail("the layout runs no program", file: file, line: line)
            return (patch, [])
        }

        program = described
        worn = layout.driven?[.parameters]?.state
        cycle()
        described.layOut(room.width, room.height)
        cycle()

        return (patch, placed)
    }
}

extension State where Value: Walked {
    /// The state's binding, the state moving under `motion` from now on: how a test gives a layout's parameters
    /// their law, which is their state's own.
    @MainActor
    func traveling(_ motion: Motion) -> Binding<Value> {
        try? projectedValue.journey.setMotion(motion)
        return projectedValue
    }
}

extension HostPatch {
    /// The layout program this patch says its element runs from now on; nil where it says none.
    var program: HostLayoutProgram? {
        if case .replace(let program)? = layout { return program }
        return nil
    }
}

extension HostPatch {
    /// The numbers the hand moves on the element this patch describes, as the host is handed them; none where it is
    /// handed no program.
    var moved: [HostInteractionValue] {
        if case .replace(let program)? = interaction { return program.values }
        return []
    }
}

extension HostPatch {
    /// The first patch of a kind, this one or however deep below it.
    func first(_ type: NodeType) -> HostPatch? {
        subtree.first { $0.type == type }
    }
}
