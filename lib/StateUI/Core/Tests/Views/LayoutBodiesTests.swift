// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A motion layout's world worked out at a fixed step: the same time in other frames brings a body to the same place, a
/// critically damped one comes onto its place without passing it and leaves the world there, a lighter damped one
/// passes it and comes back, a world far behind works out no more than its most steps, and a body carried keeps where
/// it was shown.
@MainActor
final class LayoutBodiesTests: XCTestCase {
    private let critical = LayoutBodies.Spring(response: 300, damping: 1)

    /// The world with one body 100 from its place, going nowhere, from 0.
    private func world(_ spring: LayoutBodies.Spring) -> LayoutBodies {
        var world = LayoutBodies()
        world.set(1, lanes: [100], velocity: [0], spring: spring, at: 0)
        return world
    }

    /// THE SAME TIME IN OTHER FRAMES IS THE SAME PLACE: the world steps at its own fixed step, whatever frames ask it.
    func testTheSameTimeInOtherFramesIsTheSamePlace() {
        var sixteens = world(critical), sevens = world(critical)
        for frame in 1...12 { sixteens.step(to: Double(frame) * 16) }
        for frame in 1...28 { sevens.step(to: min(Double(frame) * 7, 192)) }

        XCTAssertEqual(sixteens[1], sevens[1])
    }

    /// A CRITICALLY DAMPED BODY COMES ONTO ITS PLACE WITHOUT PASSING IT, and leaves the world at rest there.
    func testACriticallyDampedBodyComesOntoItsPlaceWithoutPassingIt() {
        var world = world(critical)
        var nearest = 100.0
        for frame in 1...200 {
            world.step(to: Double(frame) * 16)
            guard let body = world[1] else { break }
            XCTAssertGreaterThanOrEqual(body.lanes[0], -HostMotionLaw.still, "never past its place")
            XCTAssertLessThanOrEqual(body.lanes[0], nearest + 1e-9, "never back away")
            nearest = body.lanes[0]
        }
        XCTAssertTrue(world.isEmpty, "at rest, gone from the world")
    }

    /// A LIGHTER DAMPED BODY PASSES ITS PLACE AND COMES BACK.
    func testALighterDampedBodyPassesItsPlaceAndComesBack() {
        var world = world(LayoutBodies.Spring(response: 300, damping: 0.5))
        var passed = false
        for frame in 1...300 {
            world.step(to: Double(frame) * 16)
            if let body = world[1], body.lanes[0] < -1 { passed = true }
        }
        XCTAssertTrue(passed, "past its place")
        XCTAssertTrue(world.isEmpty, "and back on it, at rest")
    }

    /// A WORLD FAR BEHIND WORKS OUT NO MORE THAN ITS MOST STEPS: a second at once is 32 steps, and the rest let go.
    func testAWorldFarBehindWorksOutNoMoreThanItsMostSteps() {
        var behind = world(critical), stepped = world(critical)
        behind.step(to: 1_000)
        stepped.step(to: Double(LayoutBodies.mostSteps) * LayoutBodies.step)

        XCTAssertEqual(behind[1], stepped[1])
        behind.step(to: 1_016)
        stepped.step(to: Double(LayoutBodies.mostSteps) * LayoutBodies.step + 16)
        XCTAssertEqual(behind[1]?.lanes[0] ?? 0, stepped[1]?.lanes[0] ?? 0, accuracy: 1e-9, "going on from there")
    }

    /// A BODY CARRIED KEEPS WHERE IT WAS SHOWN: its place moved, it stands as far off the other way, and one carried
    /// by nothing makes no body.
    func testABodyCarriedKeepsWhereItWasShown() {
        var world = LayoutBodies()
        world.carry(1, by: [0], spring: critical, at: 0)
        XCTAssertNil(world[1], "carried by nothing")

        world.carry(1, by: [-40], spring: critical, at: 0)
        world.carry(1, by: [-10], spring: critical, at: 0)
        XCTAssertEqual(world[1]?.lanes, [-50])
        XCTAssertEqual(world[1]?.velocity, [0])
    }
}

/// A view of a motion layout following its place as a body: it lags behind its place as the phase moves it, passes it
/// on a spring damped below 1, and settles onto it; a view of the world's own goes with its place exactly.
@MainActor
final class LayoutFollowerTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// Two views a hundred apart a unit of the phase: the first following its place, the second the world's own.
    private func tree(_ phase: State<Double>) -> Node {
        MotionLayout([0, 1], parameters: phase.projectedValue) { index in
            if index == 0 {
                Text("\(index)").layoutBody(.followsLayout(.spring(response: .milliseconds(400), damping: 0.5)))
            } else {
                Text("\(index)")
            }
        } placements: { _, at in
            [Placement(Rect(at * 100, 0, 10, 10)), Placement(Rect(at * 100, 20, 10, 10))]
        }
        .motion(.none)
        .node
    }

    /// A VIEW FOLLOWING ITS LAYOUT WEARS THE BODY THAT FOLLOWS IT: `.followsLayout(spring)` writes what
    /// `.layoutBody(.followsLayout(spring))` does.
    func testAViewFollowingItsLayoutWearsTheBodyThatFollowsIt() {
        let spring = Motion.spring(response: .milliseconds(420), damping: 0.55)
        let short = Text("a").followsLayout(spring).node
        let whole = Text("a").layoutBody(.followsLayout(spring)).node

        XCTAssertEqual(short.props[.layoutBody], whole.props[.layoutBody])
        XCTAssertEqual(short.props[.layoutBody], LayoutBody.followsLayout(spring).propValue)
    }

    /// A VIEW'S BODY FOLLOWS THE STATE ITS VIEW READS: a switch the views' own closure reads turns their bodies on,
    /// the layout described again for that alone - nothing around it built.
    func testAViewsBodyFollowsTheStateItsViewReads() throws {
        try bodyFollowsTheStateItsViewReads(shaded: false)
        try bodyFollowsTheStateItsViewReads(shaded: true)
    }

    /// The same, the views held as a shaded layout holds them.
    private func bodyFollowsTheStateItsViewReads(shaded: Bool) throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
        let (phase, sways) = (State(wrappedValue: 0.0), State(wrappedValue: false))
        let renders = Renders()
        func built() -> Node {
            let layout = MotionLayout([0], parameters: phase.projectedValue) { index in
                if sways.wrappedValue {
                    Text("\(index)").followsLayout(.spring(response: .milliseconds(400), damping: 0.5))
                } else {
                    Text("\(index)")
                }
            } placements: { _, at in
                [Placement(Rect(at * 100, 0, 10, 10))]
            }
            .motion(.none)
            return (shaded ? layout.shade(Rectangle()) : layout).node
        }
        let layout = try XCTUnwrap(bench.laid(renders, built).patch.first(.motionLayout))
        let (worn, area) = (try XCTUnwrap(layout.driven?[.parameters]?.state), try XCTUnwrap(layout.driven?[.area]?.state))
        // Read off the run as the host does, no tree described again: a new description would read the bodies anew.
        func shown() -> Double { standing(area, as: PlacedRun.self)?.placements.first?.bounds.x ?? -1 }
        moved(worn, to: [1, 1, 0], mask: 0b111)
        bench.cycle()
        XCTAssertEqual(shown(), 100, accuracy: 0.000_1, "no body yet: with its place (shaded \(shaded))")

        sways.wrappedValue = true
        renders.revisit(changed: Renderer.shared.pendingChanges)
        moved(worn, to: [2, 2, 0], mask: 0b111)
        bench.cycle()
        XCTAssertLessThan(shown(), 150, "a body now: behind its place as it leaps (shaded \(shaded))")
    }

    /// A BODY FOLLOWING ITS PLACE LAGS BEHIND IT, PASSES IT AND SETTLES ONTO IT; the world's own goes with its place.
    func testABodyFollowingItsPlaceLagsPassesAndSettles() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func built() -> Node { tree(phase) }
        let worn = try XCTUnwrap(bench.laid(renders, built).patch.first(.motionLayout)?.driven?[.parameters]?.state)

        moved(worn, to: [1, 1, 0], mask: 0b111)
        bench.cycle()
        let first = bench.shown(renders.renderFromScratch(built()))
        XCTAssertLessThan(first[0].bounds.x, 50, "behind its place as it leaps")
        XCTAssertEqual(first[1].bounds.x, 100, accuracy: 0.000_1, "the world's own with its place")

        var farthest = 0.0
        for _ in 0..<200 {
            bench.cycle()
            farthest = max(farthest, bench.shown(renders.renderFromScratch(built()))[0].bounds.x)
        }
        XCTAssertGreaterThan(farthest, 101, "past it")
        XCTAssertEqual(bench.shown(renders.renderFromScratch(built()))[0].bounds.x, 100, accuracy: 0.001, "onto it")
    }
}
