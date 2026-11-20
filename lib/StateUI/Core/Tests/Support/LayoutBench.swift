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
    }

    /// The program of the layout last laid or shown, which a patch names only when its description made another.
    private(set) var program: HostLayoutProgram?

    /// Where the layout of `patch` shows its views, in the items' order, as the host reads the run.
    func shown(_ patch: HostPatch) -> [Placement] {
        if let described = patch.first(.motionLayout)?.program { program = described }
        return placed
    }

    /// Where the layout last laid or shown puts its views now - a view the hand holds where it holds it - no tree
    /// described again. Bringing a view onto its place is the host's: the bench shows where it goes.
    var placed: [Placement] { program?.run?().placements ?? [] }

    /// What the layout last answered its host: each view's place, its body, and where a change measures its way to.
    var answer: HostLayoutAnswer { program?.answered() ?? HostLayoutAnswer() }

    /// The host's word that every view it moved stands at its place.
    func rest() {
        program?.bodiesMove(false)
    }

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
        guard let heard = renders.renderFromScratch(tree()).first(.motionLayout)?.events?[.itemDragUpdated] else {
            return XCTFail("the layout hears no hand on its views", file: file, line: line)
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(phase, at, velocity, still)), file: file, line: line)
        cycle()
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
