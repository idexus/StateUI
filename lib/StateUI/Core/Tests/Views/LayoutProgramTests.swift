// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout's program as the host meets it: the slot it crosses under, the description that made it, the room the
// host says and the measure it says again.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class LayoutProgramTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// How many times an arithmetic ran, a class so the closure that writes it is not walked for state.
    private final class Runs {
        var count = 0
        var rooms: [Rect] = []
    }

    /// One layout of `count` views, described anew at every call.
    private func layout(_ runs: Runs, measures: Bool = false, count: Int = 2) -> Node {
        MotionLayout(Array(0..<count), parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { context, _ in
            runs.count += 1
            runs.rooms.append(context.bounds)
            return context.subviews.map { view in
                Placement(Rect(x: 0, y: 0, width: measures ? view.sizeThatFits().width : 10, height: 10))
            }
        }
        .node
    }

    /// THE PROGRAM IS A MEMBER OF THE LAYOUT'S CONTRACT, and crosses in the patch as it is: under the layout's
    /// slot, numbered by the description that made it.
    func testTheProgramCrossesInThePatch() throws {
        let renders = Renders()
        let patch = renders.render(layout(Runs()))
        let program = try XCTUnwrap(patch.first(.motionLayout)?.program)

        XCTAssertGreaterThan(program.slot, 0)
        XCTAssertEqual(MotionLayoutContract.layout.name, "layout")
        XCTAssertNil(program.measure, "a layout that measures nothing says no size of its own")
    }

    /// THE PROGRAM ANSWERS THE PLACES AT ANY PARAMETERS, WITH NOTHING WRITTEN: what the run answered where it
    /// stands, and the places anywhere else - asked by a host in its own frame, which moves no state of the
    /// layout and leaves what the run answered as it was.
    func testTheProgramAnswersThePlacesAtAnyParametersWithNothingWritten() throws {
        let (renders, bench, turn) = (Renders(), LayoutBench(), State(wrappedValue: 0.0))
        func tree() -> Node {
            MotionLayout([0, 1, 2], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<3).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 100, height: 50)) }
            }
            .node
        }
        _ = bench.laid(renders, tree)
        let place = try XCTUnwrap(bench.program?.place)
        let answered = bench.answer

        XCTAssertEqual(place([0], [0], 300, 200).views.map(\.target), answered.views.map(\.target), "where it stands")
        XCTAssertEqual(place([0], [0], 300, 200).views.map(\.key), answered.views.map(\.key), "the same views")
        XCTAssertEqual(place([1.5], [0], 300, 200).views.map(\.target.bounds.x), [-150, -50, 50], "and anywhere else")
        XCTAssertEqual(place([1.5], [0], 0, 0).views.count, 0, "no room, no place")

        XCTAssertEqual(turn.wrappedValue, 0, "no state of the layout moved")
        XCTAssertEqual(bench.answer.views.map(\.target), answered.views.map(\.target), "what the run answered stands")
    }

    /// THE ARITHMETIC IS HANDED WHERE THE MOTION SET OUT AS THE HOST SAYS IT, and - asked at no parameters -
    /// where the layout stands.
    func testTheArithmeticIsHandedWhereTheHostSaysTheMotionSetOut() throws {
        let (renders, bench, turn) = (Renders(), LayoutBench(), State(wrappedValue: 2.0))
        func tree() -> Node {
            MotionLayout([0], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, at, from in
                [Placement(Rect(x: from * 100, y: at * 10, width: 10, height: 10))]
            }
            .axis(range: 0...6, segments: .every(1))
            .node
        }
        _ = bench.laid(renders, tree)
        let place = try XCTUnwrap(bench.program?.place)

        XCTAssertEqual(bench.answer.views[0].target.bounds, Rect(x: 200, y: 20, width: 10, height: 10), "at rest: there")
        XCTAssertEqual(
            place([2.5], [1], 300, 200).views[0].target.bounds, Rect(x: 100, y: 25, width: 10, height: 10),
            "on its way: from where the host says")
    }

    /// THE PROGRAM SAYS ITS AXES' MARKS, AND AN AXIS SAYS THE LAST IT PASSED: what the host keeps where a motion
    /// set out by - going up the last mark at or under where it stands, going down the last at or over it, none
    /// between two marks, and round a turn where the axis comes round.
    func testTheProgramSaysItsAxesMarksAndTheLastPassed() throws {
        let (renders, bench, turn) = (Renders(), LayoutBench(), State(wrappedValue: 0.0))
        func tree() -> Node {
            MotionLayout([0, 1, 2, 3], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<4).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 100, height: 50)) }
            }
            .axis(range: 0...3, segments: .every(1))
            .node
        }
        _ = bench.laid(renders, tree)
        let axis = try XCTUnwrap(bench.program?.axes.first)

        XCTAssertEqual(axis, HostLayoutAxis(lane: 0, segments: [0, 1, 2, 3]))
        XCTAssertEqual(axis.passed(from: 0.2, to: 2.4), 2, "the last passed going up")
        XCTAssertEqual(axis.passed(from: 2.4, to: 0.2), 1, "and going down")
        XCTAssertEqual(axis.passed(from: 0.2, to: 2), 2, "standing on a mark has passed it")
        XCTAssertNil(axis.passed(from: 0.2, to: 0.8), "none between two marks")

        let round = HostLayoutAxis(lane: 0, segments: [0, 1, 2], turn: (low: 0, period: 3))
        XCTAssertEqual(round.passed(from: 2.5, to: 3.4), 3, "round the turn")
        XCTAssertEqual(round.passed(from: 0.4, to: -0.5), 0)
    }

    /// THE SLOT STANDS WHILE THE LAYOUT STANDS; the description is another at every build of it.
    func testTheSlotStandsAndTheRevisionMoves() throws {
        let renders = Renders()
        let runs = Runs()
        let first = try XCTUnwrap(renders.render(layout(runs)).first(.motionLayout)?.program)
        let second = try XCTUnwrap(renders.render(layout(runs, count: 3)).first(.motionLayout)?.program)

        XCTAssertEqual(second.slot, first.slot, "the same layout")
        XCTAssertNotEqual(second.revision, first.revision, "another description of it")
    }

    /// NOTHING IS PLACED BEFORE THE HOST SAYS A ROOM; the room it says is the arithmetic's, from the layout's own
    /// top left; and a room said again as it stands asks nothing.
    func testTheRoomTheHostSaysIsWorkedOutOnce() throws {
        let runs = Runs()
        let renders = Renders()
        let program = try XCTUnwrap(bench.takes(renders.render(layout(runs))))
        bench.cycle()
        XCTAssertEqual(program.answered().views.count, 0, "no room, no places")

        program.layOut(300, 200)
        bench.cycle()
        XCTAssertEqual(runs.rooms.last, Rect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(program.answered().views.count, 2)

        let ran = runs.count
        program.layOut(300, 200)
        bench.cycle()
        XCTAssertEqual(runs.count, ran, "the same room: nothing worked out again")

        program.layOut(320, 200)
        bench.cycle()
        XCTAssertEqual(runs.rooms.last, Rect(x: 0, y: 0, width: 320, height: 200))
    }

    /// A MEASURE SAID AGAIN WORKS OUT A LAYOUT THAT MEASURED, and leaves one that measured nothing as it stood.
    func testAMeasureSaidAgainWorksOutOnlyALayoutThatMeasured() throws {
        for measures in [true, false] {
            let runs = Runs()
            let renders = Renders()
            let program = try XCTUnwrap(bench.takes(renders.render(layout(runs, measures: measures))))
            program.layOut(300, 200)
            bench.cycle()
            let ran = runs.count

            program.measuredBy { place, _, _ in
                HostChildMeasured(size: LayoutSize(width: Double(place + 1) * 30, height: 10), firstBaseline: nil)
            }
            bench.cycle()

            if measures {
                XCTAssertEqual(runs.count, ran + 1, "its views may measure otherwise")
                XCTAssertEqual(program.answered().views.map(\.target.bounds.width), [30, 60])
            } else {
                XCTAssertEqual(runs.count, ran, "it reads no view's size")
            }
        }
    }

    // MARK: - What a layout follows

    /// What a layout's arithmetic read of a journey, and how many views were built.
    private final class Read {
        var samples: [Double?] = []
        var views = 0
    }

    /// A layout whose arithmetic samples `tilt`'s journey, and follows it.
    private func tilted(_ tilt: State<Double>, _ read: Read) -> Node {
        MotionLayout([0], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
            read.views += 1
            return Text("card")
        } placements: { _, _ in
            let sample = tilt.projectedValue.journey.sample
            read.samples.append(sample?.value)
            return [Placement(Rect(x: sample?.value ?? 0, y: 0, width: 10, height: 10))]
        }
        .following(tilt.projectedValue.journey)
        .node
    }

    /// A LAYOUT FOLLOWING A JOURNEY IS A CONSUMER of the state's channel while it stands: the host is told to
    /// carry the state though no property shows it, and lets it go with the layout.
    func testALayoutFollowingAJourneyIsAConsumer() throws {
        let tilt = State(wrappedValue: 0.0)
        let renders = Renders()

        let layout = tilted(tilt, Read())
        let mounted = renders.render(ZStack { BuiltViews(nodes: [layout]) }.id("root").node)
        let image = try XCTUnwrap(tilt.storage.image)

        XCTAssertEqual(image.consumers, 1)
        XCTAssertTrue(image.hasChannel)
        XCTAssertTrue(
            mounted.subtree.contains { patch in
                if case .replace(let followed)? = patch.followed { return followed.contains { $0.state == tilt.number } }
                return false
            }, "the host is told the layout follows the state")

        renders.render(ZStack {}.id("root").node)
        XCTAssertEqual(image.consumers, 0)
        XCTAssertFalse(image.hasChannel, "the layout gone, the channel went with its last consumer")
    }

    /// A FRAME OF THE JOURNEY WAKES THE PROGRAM ALONE: the arithmetic runs again and reads the frame's sample, no
    /// view is built; where the state is going, written, is no frame and runs nothing.
    func testAFrameOfAFollowedJourneyRunsTheArithmeticAlone() throws {
        let tilt = State(wrappedValue: 0.0)
        let read = Read()
        let (_, _) = bench.laid(Renders(), { tilted(tilt, read) })
        let (ran, built) = (read.samples.count, read.views)

        tilt.wrappedValue = 40
        bench.cycle()
        XCTAssertEqual(read.samples.count, ran, "a destination written is no frame")

        let (binding, standing) = try XCTUnwrap(HostAnimatorReport.standing(tilt.number))
        let journey = HostJourney(
            value: [12], destination: [40], velocity: [300], motion: standing.motion, completion: standing.completion,
            stopped: standing.stopped)
        XCTAssertTrue(HostBoundary.report(journey, updating: .frame, through: binding, at: 1_000))
        bench.cycle()

        XCTAssertEqual(read.samples.count, ran + 1, "the frame ran the arithmetic once")
        XCTAssertEqual(read.samples.last, 12, "which read the frame's sample")
        XCTAssertEqual(bench.placed.first?.bounds.x, 12)
        XCTAssertEqual(read.views, built, "and built no view")
    }
}
