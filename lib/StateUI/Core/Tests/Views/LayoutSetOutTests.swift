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
        let worn = try XCTUnwrap(bench.laid(renders, built).patch.first(.motionLayout)?.driven?[.parameters]?.state)

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

}
