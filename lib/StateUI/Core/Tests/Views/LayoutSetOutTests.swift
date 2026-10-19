// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// Where a layout's motion set out: the phase the run stood at when the hand, a throw or a journey of the phase took
/// it away, handed to the arithmetic beside the phase until the run rests again - the way it goes is the phase's
/// side of it.
@MainActor
final class LayoutSetOutTests: XCTestCase {
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
        LayoutEngine([1]) { Text("\($0)") } placements: { _, at, from in
            handed.phases.append(at)
            handed.froms.append(from)
            return [Placement(Rect(0, 0, 10, 10))]
        }
        .phase(phase.projectedValue)
        .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...6, snaps: .every(1))
        .node
    }

    /// AT REST, THE RUN SETS OUT FROM WHERE IT STANDS.
    func testAtRestItSetsOutFromWhereItStands() {
        let phase = State(wrappedValue: 2.0)
        let handed = Handed()
        let renders = Renders()

        _ = bench.laid(renders) { tree(phase, handed) }

        XCTAssertEqual(handed.froms.last, 2)
    }

    /// A JOURNEY OF THE PHASE keeps where it set out until it passes a target, and lands where it sets out next.
    func testAJourneyKeepsWhereItSetOutUntilItLands() async throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        let worn = try XCTUnwrap(bench.laid(renders, built).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        phase.wrappedValue = 3
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        _ = await settle()
        bench.cycle()
        moved(worn, to: 1.5)
        bench.cycle()
        XCTAssertEqual(handed.phases.last, 1.5, "on its way")
        XCTAssertEqual(handed.froms.last, 1, "from where it stood")

        moved(worn, to: 2.5)
        bench.cycle()
        XCTAssertEqual(handed.froms.last, 2, "from the target it passed")

        moved(worn, to: [3, 3, 0], mask: 0b111)
        bench.cycle()
        XCTAssertEqual(handed.froms.last, 3, "landed")
    }

    /// THE HAND, ON AND BACK, keeps where it set out: back past it, the run goes the other way from the same place,
    /// so nothing the arithmetic draws from it jumps.
    func testTheHandKeepsWhereItSetOutOnAndBack() throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1.6, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 1, "on")

        bench.hand(renders, built, .changed, moved: Point(130, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.3, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 1, "back past it, from the same place")
    }

    /// PASSING A TARGET, THE MOTION SETS OUT FROM IT, whichever way: there every view stands at a whole step, so
    /// nothing drawn from it jumps - one long hand moves the cards on one by one, as two hands would.
    func testPassingATargetSetsOutFromIt() throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-130, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 2.3, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 2, "past 2")

        bench.hand(renders, built, .changed, moved: Point(80, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 2, "back, but 1 not passed")

        bench.hand(renders, built, .changed, moved: Point(60, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(handed.froms.last, 1, "past 1 the other way")
    }

    /// A HAND TAKING THE RUN ON ITS WAY keeps where it set out: the card it catches goes on with it, either way.
    func testAHandTakingTheRunOnItsWayKeepsWhereItSetOut() async throws {
        let phase = State(wrappedValue: 1.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        let worn = try XCTUnwrap(bench.laid(renders, built).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        phase.wrappedValue = 2
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        _ = await settle()
        bench.cycle()
        moved(worn, to: 1.8)
        bench.cycle()

        bench.hand(renders, built, .began)
        XCTAssertEqual(handed.phases.last ?? 0, 1.8, accuracy: 0.001, "taken where it is shown")
        XCTAssertEqual(handed.froms.last, 1, "from where it set out")

        bench.hand(renders, built, .changed, moved: Point(-30, 0))
        XCTAssertEqual(handed.froms.last, 2, "until it passes the next")
    }

    /// A THROW ACROSS SEVERAL TARGETS sets out from each as it passes it, and rests on the last.
    func testAThrowSetsOutFromEachTargetItPasses() {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func built() -> Node { tree(phase, handed) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .ended, speed: Point(-1_500, 0))
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
}
