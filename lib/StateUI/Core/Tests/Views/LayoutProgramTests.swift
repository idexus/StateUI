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
                Placement(Rect(0, 0, measures ? view.sizeThatFits().width : 10, 10))
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
        let program = try XCTUnwrap(renders.render(layout(runs)).first(.motionLayout)?.program)
        bench.cycle()
        XCTAssertEqual(program.answered().views.count, 0, "no room, no places")

        program.layOut(300, 200)
        bench.cycle()
        XCTAssertEqual(runs.rooms.last, Rect(0, 0, 300, 200))
        XCTAssertEqual(program.answered().views.count, 2)

        let ran = runs.count
        program.layOut(300, 200)
        bench.cycle()
        XCTAssertEqual(runs.count, ran, "the same room: nothing worked out again")

        program.layOut(320, 200)
        bench.cycle()
        XCTAssertEqual(runs.rooms.last, Rect(0, 0, 320, 200))
    }

    /// A MEASURE SAID AGAIN WORKS OUT A LAYOUT THAT MEASURED, and leaves one that measured nothing as it stood.
    func testAMeasureSaidAgainWorksOutOnlyALayoutThatMeasured() throws {
        for measures in [true, false] {
            let runs = Runs()
            let renders = Renders()
            let program = try XCTUnwrap(renders.render(layout(runs, measures: measures)).first(.motionLayout)?.program)
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
            return [Placement(Rect(sample?.value ?? 0, 0, 10, 10))]
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
