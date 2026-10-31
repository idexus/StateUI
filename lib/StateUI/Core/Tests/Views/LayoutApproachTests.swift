// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// How a run let go comes onto the next target, as the host walks the journey it sends: never slower than the
/// layout's motion moves a unit - let go still, or by a hand slower than that, it approaches the target under the
/// motion's curve over as much of its length as the way left is of a unit.
@MainActor
final class LayoutApproachTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
        bench.walks = true
    }

    private let bench = LayoutBench()

    /// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
    private final class Handed {
        var phases: [Double] = []
    }

    /// One view moved a hundred points a unit, under a linear motion of 320 milliseconds: a unit a 320 ms, 0.05 a
    /// frame.
    private func tree(_ phase: State<Double>, _ handed: Handed, _ motion: Motion = .eased(.milliseconds(320), .linear))
        -> Node
    {
        MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            handed.phases.append(at)
            return [Placement(Rect(0, 0, 10, 10))]
        }
        .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...2, snaps: .every(1))
        .motion(motion)
        .node
    }

    /// Where the run is shown after each frame from the lift on.
    private func flight(_ handed: Handed) -> [Double] {
        (0..<40).map { _ in
            bench.cycle()
            return handed.phases.last ?? .nan
        }
    }

    /// LET GO STILL SHORT OF THE NEXT TARGET, THE RUN APPROACHES IT A UNIT A MOTION'S LENGTH: 0.4 left of a linear
    /// 320 ms is 128 ms, 0.05 a frame - not the whole 320 ms for the short way.
    func testLetGoStillTheRunApproachesTheNextTargetAUnitAMotionsLength() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        bench.hand(renders, built, .ended)
        XCTAssertEqual(phase.wrappedValue, 1, "named at once")

        let flown = flight(handed)
        XCTAssertEqual(flown[0], 0.65, accuracy: 0.001, "a frame on from where the hand left it")
        XCTAssertEqual(flown[3], 0.8, accuracy: 0.001, "a unit in 320 ms")
        XCTAssertEqual(flown[7], 1, accuracy: 0.000_1, "there in 128 ms")
    }

    /// A HAND SLOWER THAN THAT approaches the next target alike: thrown at 0.6 units a second, it would crawl the
    /// 0.4 on the throw's curve; it goes a unit a motion's length.
    func testAHandSlowerThanTheMotionApproachesTheNextTargetAlike() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        bench.hand(renders, built, .ended, speed: Point(-60, 0))
        XCTAssertEqual(phase.wrappedValue, 1)

        let flown = flight(handed)
        XCTAssertEqual(flown[3], 0.8, accuracy: 0.001, "a unit in 320 ms")
        XCTAssertEqual(flown[7], 1, accuracy: 0.000_1)
    }

    /// LET GO BACK SHORT OF HALFWAY, THE RUN APPROACHES WHERE IT CAME FROM ALIKE.
    func testLetGoShortOfHalfwayTheRunApproachesWhereItCameFrom() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-20, 0))
        bench.hand(renders, built, .ended)
        XCTAssertEqual(phase.wrappedValue, 0)

        let flown = flight(handed)
        XCTAssertEqual(flown[1], 0.1, accuracy: 0.001, "a unit in 320 ms")
        XCTAssertEqual(flown[3], 0, accuracy: 0.000_1, "there in 64 ms")
    }

    /// A HAND FASTER THAN THAT IS A THROW, setting out at the hand's own speed.
    func testAHandFasterThanTheMotionIsAThrow() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        // 12 units a second carries the run 1.6 on: past 1 and 2 to the end, 1.4 of throw.
        bench.hand(renders, built, .ended, speed: Point(-1_200, 0))
        XCTAssertEqual(phase.wrappedValue, 2)

        let flown = flight(handed)
        XCTAssertEqual((flown[1] - flown[0]) / 0.016, 12, accuracy: 2, "about the hand's speed")
        XCTAssertLessThanOrEqual((flown[1] - flown[0]) / 0.016, 12, "never faster")
    }

    /// WHILE A THROW GOES ON, ITS JOURNEY SAYS IT: the phase's journey sets out at the hand's speed and slows onto the
    /// target as the host walks it - what a reader of `$phase.journey.velocity` and of its value meets.
    func testWhileAThrowGoesOnItsJourneySaysWhereAndHowFast() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        bench.hand(renders, built, .ended, speed: Point(-1_200, 0))
        let journey = phase.projectedValue.journey
        XCTAssertEqual(journey.velocity, 12, accuracy: 0.000_1, "setting out at the hand's speed")
        XCTAssertEqual(journey.value, 0.6, accuracy: 0.000_1, "from where it left it")

        bench.cycle()
        XCTAssertGreaterThan(journey.velocity, 0, "going on")
        XCTAssertLessThan(journey.velocity, 12, "slowing")
        XCTAssertEqual(journey.value, handed.phases.last ?? 0, accuracy: 0.000_1, "where the run is shown")

        for _ in 0..<60 { bench.cycle() }
        XCTAssertEqual(journey.velocity, 0, "at rest")
        XCTAssertEqual(journey.value, 2, "on its target")
    }

    /// A SPRING'S APPROACH settles as the spring does, its response cut to the way left: there long before the
    /// whole response would bring it.
    func testASpringsApproachIsCutToTheWayLeft() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed, .spring(response: .milliseconds(800))) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-90, 0))
        bench.hand(renders, built, .ended)

        let flown = flight(handed)
        XCTAssertEqual(flown[16], 1, accuracy: 0.002, "0.1 of 800 ms settles within 256 ms")
    }

    /// A HAND TAKING THE RUN ON ITS WAY TAKES IT WHERE IT IS SHOWN, on a throw or an approach alike - never where it
    /// is going.
    func testAHandTakingTheRunOnItsWayTakesItWhereItIsShown() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        bench.hand(renders, built, .ended, speed: Point(-1_200, 0))
        for _ in 0..<4 { bench.cycle() }
        let shown = handed.phases.last ?? 0

        bench.hand(renders, built, .began)
        XCTAssertEqual(handed.phases.last ?? 0, shown, accuracy: 0.001)
    }
}
