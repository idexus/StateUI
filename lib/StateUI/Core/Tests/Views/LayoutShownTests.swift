// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// Where a layout's run is shown is its phase's journey value while the hand, a throw or an approach moves it: the
/// state's own value names the target, and anything following the phase - another layout, an engine writing a
/// channel - goes with the hand.
@MainActor
final class LayoutShownTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// What an engine following the phase read, a class so the closure that writes it is not walked for state.
    private final class Read {
        var values: [Double] = []
        var bodies = 0
    }

    /// A run of three views moved a hundred points a unit, and beside it a view whose engine follows the phase.
    private func tree(_ phase: State<Double>, _ read: Read) -> Node {
        ZStack {
            PhaseLayout([0, 1, 2], phase: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<3).map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
            }
            .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...2, snaps: .every(1))
            .motion(.eased(.milliseconds(160), .linear))

            Rectangle()
                .fill(.red)
                .engine(following: phase.projectedValue) { _ in read.values.append(phase.projectedValue.journey.value) }
        }
        .node
    }

    /// THE HAND'S PLACE IS THE PHASE'S VALUE, its target the state's own.
    func testTheHandsPlaceIsThePhasesValue() {
        let (phase, read, renders) = (State(wrappedValue: 0.0), Read(), Renders())
        func built() -> Node { tree(phase, read) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-60, 0))

        XCTAssertEqual(phase.wrappedValue, 1, "the target named")
        XCTAssertEqual(phase.projectedValue.journey.value, 0.6, accuracy: 0.001, "where the hand holds the run")
    }

    /// AN ENGINE FOLLOWING THE PHASE GOES WITH THE HAND, move by move, and with the run as it comes onto its target.
    func testAnEngineFollowingThePhaseGoesWithTheHand() {
        bench.walks = true
        let (phase, read, renders) = (State(wrappedValue: 0.0), Read(), Renders())
        func built() -> Node { tree(phase, read) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-20, 0))
        bench.cycle()
        XCTAssertEqual(read.values.last ?? 0, 0.2, accuracy: 0.001)
        bench.hand(renders, built, .changed, moved: Point(-20, 0))
        bench.cycle()
        XCTAssertEqual(read.values.last ?? 0, 0.4, accuracy: 0.001)

        bench.hand(renders, built, .ended)
        bench.cycle()
        XCTAssertLessThan(read.values.last ?? 0, 0.4, "on its way back")
        for _ in 0..<20 { bench.cycle() }
        XCTAssertEqual(read.values.last ?? 1, 0, accuracy: 0.000_1, "and on its target")
        XCTAssertEqual(phase.projectedValue.journey.value, 0, accuracy: 0.000_1, "the value the target at rest")
    }
}
