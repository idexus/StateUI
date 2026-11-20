// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A swipe: one hand moves the run one snap target at most, either way from where it took it, the view in front
/// under the hand by a unit measured as it takes the run.
@MainActor
final class LayoutSwipeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
    private final class Handed {
        var phases: [Double] = []
    }

    /// Five views a hundred points apart, swiped a hundred points a unit.
    private func row(_ phase: State<Double>, _ handed: Handed) -> Node {
        MotionLayout([0, 1, 2, 3, 4], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            handed.phases.append(at)
            return (0..<5).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
        }
        .interaction(
            .value(phase.projectedValue, input: .swipe(.horizontal, unit: .points(100))).reversed(true).range(0...4).snaps(.every(1))
                .release(.projected(.eased(.milliseconds(400)))))
        .node
    }

    /// A SWIPE MOVES THE RUN ONE TARGET AT MOST, either way, however far the hand goes.
    func testASwipeMovesTheRunOneTargetAtMost() {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        func built() -> Node { row(phase, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -500, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 2, accuracy: 0.000_1, "one on, not five")

        bench.hand(.changed, moved: Point(x: 900, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0, accuracy: 0.000_1, "one back from where it took it")

        bench.hand(.ended)
        XCTAssertEqual(phase.wrappedValue, 0)
    }

    /// THROWN, A SWIPE GOES ON TO THE NEXT TARGET THAT WAY, however hard - and back to where it took the run when
    /// thrown back from beyond it.
    func testAThrownSwipeGoesOnToTheNextTargetThatWay() {
        let phase = State(wrappedValue: 1.0)
        func built() -> Node { row(phase, Handed()) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -10, y: 0))
        bench.hand(.ended, velocity: Point(x: -100_000, y: 0))
        XCTAssertEqual(phase.wrappedValue, 2, "the next, not the last")

        for _ in 0..<400 { bench.cycle() }
        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -80, y: 0))
        bench.hand(.ended, velocity: Point(x: 2_000, y: 0))
        XCTAssertEqual(phase.wrappedValue, 2, "thrown back from 2.8, to where it took it")
    }

    /// LET GO STILL, A SWIPE RESTS ON THE NEAREST of where it took the run and the targets either side.
    func testLetGoStillASwipeRestsOnTheNearest() {
        let phase = State(wrappedValue: 1.0)
        func built() -> Node { row(phase, Handed()) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -40, y: 0))
        bench.hand(.ended)

        XCTAssertEqual(phase.wrappedValue, 1, "short of halfway, back")
    }

    /// A WHEEL'S NOTCHES SWIPE ONE TARGET TOO: once the run rests, a notch swipes it on, and the notches that come
    /// while it goes - the rest of a burst, a spring passing its target - wait for it.
    func testAWheelsNotchesSwipeOneTargetFromRest() throws {
        let phase = State(wrappedValue: 1.0)
        func built() -> Node { row(phase, Handed()) }
        bench.laid(built)

        bench.step(Point(x: -1, y: 0))
        bench.step(Point(x: -1, y: 0))
        bench.step(Point(x: -2, y: 0))
        XCTAssertEqual(phase.wrappedValue, 2, "a burst of notches is one swipe")

        bench.cycle()
        bench.step(Point(x: -1, y: 0))
        XCTAssertEqual(phase.wrappedValue, 2, "on its way, the run still goes: the wheel waits")
        bench.step(Point(x: 1, y: 0))
        XCTAssertEqual(phase.wrappedValue, 2, "either way")

        bench.frames(60)
        bench.step(Point(x: 1, y: 0))
        bench.step(Point(x: 1, y: 0))
        XCTAssertEqual(phase.wrappedValue, 1, "at rest, the next burst swipes on, one target")
    }

    /// A PAGE IS THE ROOM'S LENGTH: pages are swiped a page a hand, the hand traveling the room's width for one -
    /// a board is a screen however the room turns.
    func testAPageIsTheRoomsLength() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func built() -> Node {
            MotionLayout([0, 1, 2], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                handed.phases.append(at)
                return (0..<3).map { _ in Placement(Rect(x: 0, y: 0, width: 10, height: 10)) }
            }
            .interaction(
                .value(phase.projectedValue, input: .swipe(.horizontal, unit: .containerLength)).reversed(true).range(0...2).snaps(.every(1))
                    .release(.projected(.eased(.milliseconds(400)))))
            .node
        }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -150, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.5, accuracy: 0.001, "half the room's 300 points, half a page")

        bench.hand(.changed, moved: Point(x: -2_000, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1, accuracy: 0.001, "a page a hand")
    }

    /// WITH NO UNIT GIVEN, A SWIPE MEASURES ONE AS IT TAKES THE RUN, as if the run stood on the target nearest, and
    /// keeps it: the view in front slowing on its way does not quicken the hand.
    func testASwipeMeasuresItsUnitAsItTakesTheRun() {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        func built() -> Node {
            MotionLayout([0], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                handed.phases.append(at)
                // Two hundred points a unit for half a unit either side of 1, fifty beyond.
                let away = abs(at - 1)
                let x = away <= 0.5 ? away * 200 : 100 + (away - 0.5) * 50
                return [Placement(Rect(x: at > 1 ? -x : x, y: 0, width: 10, height: 10))]
            }
            .interaction(
                .value(phase.projectedValue, input: .swipe(.horizontal, unit: .frontItem)).reversed(true).range(0...3).snaps(.every(1))
                    .release(.projected(.eased(.milliseconds(400)))))
            .node
        }
        bench.laid(built)

        bench.hand(.began)
        for _ in 0..<15 { bench.hand(.changed, moved: Point(x: -10, y: 0)) }

        XCTAssertEqual(handed.phases.last ?? 0, 1.75, accuracy: 0.001, "150 points at 200 a unit")
    }
}
