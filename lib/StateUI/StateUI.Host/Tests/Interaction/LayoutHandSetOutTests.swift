// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// Where a layout's motion set out under the hand: the phase the run stood at when the hand or a throw took it away,
/// handed to the arithmetic beside the phase until the run rests again, each snap it passes the next place it set
/// out from.
@MainActor
final class LayoutHandSetOutTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// What the arithmetic was handed each run, a class so the closure that writes it is not walked for state.
    private final class Handed {
        var phases: [Double] = []
        var froms: [Double] = []
    }

    /// One view whose arithmetic notes what it is handed, moved by the hand a hundred points a unit.
    private func tree(_ phase: State<Double>, _ handed: Handed) -> Node {
        MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at, from in
            handed.phases.append(at)
            handed.froms.append(from)
            return [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
        }
        .axis(range: 0...6, segments: .every(1))
        .interaction(
            .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...6).snaps(.every(1))
                .release(.projected(.eased(.milliseconds(400)))))
        .node
    }

    /// THE HAND, ON AND BACK, keeps where it set out: back past it, the run goes the other way from the same place,
    /// so nothing the arithmetic draws from it jumps.
    func testTheHandKeepsWhereItSetOutOnAndBack() throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        func built() -> Node { tree(phase, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -60, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1.6, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 1, "on")

        bench.hand(.changed, moved: Point(x: 130, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.3, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 1, "back past it, from the same place")
    }

    /// PASSING A TARGET, THE MOTION SETS OUT FROM IT, whichever way: there every view stands at a whole step, so
    /// nothing drawn from it jumps - one long hand moves the cards on one by one, as two hands would.
    func testPassingATargetSetsOutFromIt() throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        func built() -> Node { tree(phase, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -130, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 2.3, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 2, "past 2")

        bench.hand(.changed, moved: Point(x: 80, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 2, "back, but 1 not passed")

        bench.hand(.changed, moved: Point(x: 60, y: 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 1, "past 1 the other way")
    }

    /// A HAND TAKING THE RUN ON ITS WAY keeps where it set out: the card it catches goes on with it, either way.
    func testAHandTakingTheRunOnItsWayKeepsWhereItSetOut() throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        func built() -> Node { tree(phase, handed) }
        _ = phase.traveling(.eased(.milliseconds(320), curve: .linear))
        bench.laid(built)

        phase.wrappedValue = 2
        bench.frames(8)
        let shown = try XCTUnwrap(handed.phases.last)
        XCTAssertGreaterThan(shown, 1.1, "on its way")
        XCTAssertLessThan(shown, 1.9)

        bench.hand(.began)
        XCTAssertEqual(handed.phases.last ?? 0, shown, accuracy: 0.001, "taken where it is shown")
        XCTAssertEqual(handed.froms.last, 1, "from where it set out")

        bench.hand(.changed, moved: Point(x: -(2 - shown) * 100 - 10, y: 0))
        XCTAssertEqual(handed.froms.last, 2, "until it passes the next")
    }

    /// A THROW ACROSS SEVERAL TARGETS sets out from each as it passes it, and rests on the last.
    func testAThrowSetsOutFromEachTargetItPasses() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func built() -> Node { tree(phase, handed) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.ended, velocity: Point(x: -1_500, y: 0))
        bench.cycle()
        XCTAssertGreaterThan(handed.phases.last ?? 0, 0, "thrown")
        XCTAssertEqual(handed.froms.last, 0, "from where the hand took it")

        for _ in 0..<400 { bench.cycle() }
        XCTAssertGreaterThan(phase.wrappedValue, 1, "past a target")
        XCTAssertEqual(Set(handed.froms).sorted(), (0...Int(phase.wrappedValue)).map(Double.init), "each in turn")
        XCTAssertEqual(handed.froms, handed.froms.sorted(), "never back")
        XCTAssertEqual(handed.phases.last ?? 0, phase.wrappedValue, accuracy: 0.000_1, "at rest")
        XCTAssertEqual(handed.froms.last, phase.wrappedValue, "and setting out from there")
    }

    /// A NEW PLACE THE MOTION SET OUT FROM IS A CHANGE: arithmetic that reads it is answered anew where the run
    /// stood, as a change of the layout.
    func testANewSetOutIsAChange() throws {
        let phase = State(wrappedValue: 1.0)
        func tree() -> Node {
            MotionLayout([0], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _, from in [Placement(Rect(x: from * 100, y: 0, width: 10, height: 10))] }
                .axis(range: 0...3, segments: .every(1))
                .interaction(
                    .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3).snaps(.every(1))
                        .release(.projected(.eased(.milliseconds(400)))))
                .layoutBodies(.onChange(response: .milliseconds(160)))
                .node
        }
        bench.laid(tree)
        let stood = bench.answer

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -120, y: 0))
        bench.cycle()

        XCTAssertEqual(stood.views[0].target.bounds.x, 100, accuracy: 0.001, "where it stood")
        XCTAssertEqual(bench.answer.views[0].target.bounds.x, 200, accuracy: 0.001, "where it sets out from now")
        XCTAssertEqual(try XCTUnwrap(bench.answer.views[0].discrete).bounds.x, 200, accuracy: 0.001)
        XCTAssertNotEqual(bench.answer.change, stood.change)
    }

    /// WHERE THE MOTION SET OUT ASKS AGAIN ONLY AN ARITHMETIC HANDED IT: the hand passing a segment's start sets the
    /// motion out from there anew, and an arithmetic asked at keyframes alone is asked there again only if it reads
    /// where the motion set out.
    func testWhereTheMotionSetOutAsksAgainOnlyAnArithmeticHandedIt() {
        /// Two views a hundred points across a unit of the phase, the first down by its square.
        func poses(_ phase: Double) -> [Placement] {
            [Placement(Rect(x: phase * 100, y: phase * phase * 10, width: 10, height: 10)), Placement(Rect(x: phase * 100 + 10, y: 0, width: 10, height: 10))]
        }
        for readsFrom in [false, true] {
            let (phase, handed) = (State(wrappedValue: 0.0), Handed())
            func built() -> Node {
                let layout = readsFrom
                    ? MotionLayout([0, 1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at, _ in
                        handed.phases.append(at)
                        return poses(at)
                    }
                    : MotionLayout([0, 1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                        handed.phases.append(at)
                        return poses(at)
                    }
                return layout
                    .axis(range: 0...2, keyframes: .every(1), segments: .every(1))
                    .interaction(
                        .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100)))
                            .reversed(true).range(0...2).snaps(.every(1))
                            .release(.projected(.eased(.milliseconds(400)))))
                    .node
            }
            let bench = LayoutBench()
            bench.laid(built)

            bench.hand(.began)
            for _ in 0..<8 { bench.hand(.changed, moved: Point(x: -20, y: 0)) }

            let asked = handed.phases.filter { $0 == 1 }.count
            XCTAssertEqual(asked, readsFrom ? 2 : 1, "asked at 1 \(readsFrom ? "again as the hand passes it" : "once")")
        }
    }
}
