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

    /// Where the layout of `patch` shows its views, in the items' order, as the host reads the run.
    func shown(_ patch: HostPatch) -> [Placement] {
        guard let placed = patch.first(.motionLayout)?.driven?[.area]?.state else { return [] }
        return standing(placed, as: PlacedRun.self)?.placements ?? []
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
        guard let (from, began) = walk else { return reported = (standing.value, standing.velocity) }

        let law = from.motion.resolved(against: StandardEnvironment.application.motion)
        let sample = HostMotionLaw.sample(
            law, elapsed: turned - began, from: from.value, destination: from.destination, velocity: from.velocity)
        let journey = HostJourney(
            value: sample.value, destination: from.destination, velocity: sample.velocity, motion: from.motion,
            completion: standing.completion, stopped: standing.stopped)
        XCTAssertTrue(HostBoundary.report(journey, updating: [.value, .velocity], through: binding), "the walk refused")
        reported = (sample.value, sample.velocity)
        if sample.rested { walk = nil }
    }

    /// One frame as the host runs it: the board's cycle, and what it wrote read out, so a report after it lands.
    func frame() {
        turned += 16
        _ = HostBoundary.cycle(now: turned, reducesMotion: false)
    }

    /// The hand over the layout `tree` describes, as a host reports it - its phase, how far it moved what is under
    /// it since the last report, and the speed it lets go at, per second - and a cycle after it.
    func hand(
        _ renders: Renders, _ tree: () -> Node, _ phase: GesturePhase, moved: Point = .zero, speed: Point = .zero,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        // The whole description: a patch says nothing of a handler that did not change.
        guard let heard = renders.renderFromScratch(tree()).first(.motionLayout)?.events?[.translationUpdated] else {
            return XCTFail("the layout hears no hand", file: file, line: line)
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(phase, moved, speed)), file: file, line: line)
        cycle()
    }

    /// Two fingers over the layout `tree` describes, as the host layer reports them - their phase, the scale and the
    /// degrees since the last report, and their speed as they lift - and a cycle after it.
    func pinch(
        _ renders: Renders, _ tree: () -> Node, _ phase: GesturePhase, scale: Double = 1, degrees: Double = 0,
        speed: Point = .zero, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let heard = renders.renderFromScratch(tree()).first(.motionLayout)?.events?[.pinchRotationUpdated] else {
            return XCTFail("the layout hears no fingers", file: file, line: line)
        }

        XCTAssertTrue(
            renders.fire(heard, with: MemberValues.encode(phase, scale, degrees, speed)), file: file, line: line)
        cycle()
    }

    /// The hand holding one view of the layout `tree` describes, as the host layer reports it - its phase, where it is
    /// in the room, its speed as it lets go, per second, and how long it has stood still - and a cycle after it.
    func item(
        _ renders: Renders, _ tree: () -> Node, _ phase: GesturePhase, at: Point, speed: Point = .zero,
        still: Double = 0, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let heard = renders.renderFromScratch(tree()).first(.motionLayout)?.events?[.itemDragUpdated] else {
            return XCTFail("the layout hears no hand on its views", file: file, line: line)
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(phase, at, speed, still)), file: file, line: line)
        cycle()
    }

    /// A wheel's notches over the layout `tree` describes, as a host reports them - across and down, the way they move
    /// what is under the hand - and a cycle after them.
    func step(
        _ renders: Renders, _ tree: () -> Node, _ notches: Point, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let heard = renders.renderFromScratch(tree()).first(.motionLayout)?.events?[.wheelStepped] else {
            return XCTFail("the layout hears no wheel's notch", file: file, line: line)
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(notches)), file: file, line: line)
        cycle()
    }

    /// Renders `tree`, feeds the layout the room `room` as the host does, and turns the board until the arithmetic
    /// has answered: the run of placements the layout's own area carries.
    func laid(
        _ renders: Renders, _ tree: () -> Node, room: Rect = Rect(10, 20, 300, 200),
        file: StaticString = #filePath, line: UInt = #line
    ) -> (patch: HostPatch, run: [Placement]) {
        let patch = renders.render(tree())

        guard let layout = patch.first(.motionLayout),
              let fed = layout.driven?[.frame]?.state,
              let placed = layout.driven?[.area]?.state
        else {
            XCTFail("the layout is placed by no number", file: file, line: line)
            return (patch, [])
        }

        // THE FIRST CYCLE OF ALL LATCHES rather than runs, so the room is fed after it.
        worn = layout.driven?[.parameters]?.state
        cycle()
        moved(fed, to: [room.x, room.y, room.width, room.height])
        cycle()

        return (patch, standing(placed, as: PlacedRun.self)?.placements ?? [])
    }
}

extension HostPatch {
    /// The first patch of a kind, this one or however deep below it.
    func first(_ type: NodeType) -> HostPatch? {
        subtree.first { $0.type == type }
    }
}
