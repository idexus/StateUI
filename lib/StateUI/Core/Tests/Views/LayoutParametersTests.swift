// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A motion layout's phase of many axes: how it lies on the host's lanes, which axis a hand moves, and where each
// axis comes to rest.

import XCTest

@_spi(Host) @testable import StateUI

/// A phase of two axes: how far a ring is turned, and how near it stands.
private struct Orbit: LayoutParameters {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
}

/// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
private final class Handed {
    var phases: [Orbit] = []
}

@MainActor
final class LayoutParametersTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The bench the layouts are rendered, told their room and turned on.
    private let bench = LayoutBench()

    // MARK: - Lanes

    /// ONE LANE AN AXIS, in the order the phase names its axes, and back only where the count matches.
    func testAPhaseLiesAsOneLaneAnAxis() {
        XCTAssertEqual(Orbit.lanes, 2)
        XCTAssertEqual(Orbit(turn: 3, zoom: 2).carried, .lanes([3, 2]))
        XCTAssertEqual(Orbit(carried: .lanes([1, 4])), Orbit(turn: 1, zoom: 4))
        XCTAssertNil(Orbit(carried: .lanes([1])), "a lane short is no phase")
    }

    /// THE ELEMENT WEARS EVERY AXIS: one state, one channel, so a write of one axis is where the host walks it.
    func testTheElementWearsEveryAxis() throws {
        let orbit = State(wrappedValue: Orbit())
        let renders = Renders()
        func tree() -> Node {
            MotionLayout([1], parameters: orbit.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .node
        }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.motionLayout)?.driven?[.parameters]?.state)

        orbit.wrappedValue.zoom = 2
        bench.cycle()

        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Orbit>.self)).destination, Orbit(turn: 0, zoom: 2))
    }

    /// THE ARITHMETIC IS HANDED EVERY AXIS where the host walks it this frame.
    func testTheArithmeticIsHandedEveryAxisAsTheHostWalksIt() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit())
        let renders = Renders()
        func tree() -> Node {
            MotionLayout([1], parameters: orbit.projectedValue) { Text("\($0)") } placements: { _, phase in
                handed.phases.append(phase)
                return [Placement(Rect(0, 0, 10, 10))]
            }
            .node
        }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.motionLayout)?.driven?[.parameters]?.state)

        orbit.wrappedValue = Orbit(turn: 1, zoom: 2)
        bench.cycle()
        moved(worn, to: [0.5, 1.5], mask: 0b11)
        bench.cycle()

        XCTAssertEqual(handed.phases.last, Orbit(turn: 0.5, zoom: 1.5))
    }

    // MARK: - The hand's axis

    // MARK: - Coming to rest

    // MARK: - The bench

    /// A layout of one view whose hand moves the turn, a hundred points a unit, over `range`, resting on `snaps`.
    private func handTree(
        _ orbit: State<Orbit>, handed: Handed? = nil, range: ClosedRange<Double>, snaps: AxisValues = .every(1)
    ) -> () -> Node {
        {
            MotionLayout([1], parameters: orbit.projectedValue) { Text("\($0)") } placements: { _, phase in
                handed?.phases.append(phase)
                return [Placement(Rect(0, 0, 10, 10))]
            }
            .interaction(
                .value(orbit.projectedValue, axis: \.turn, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(range).snaps(snaps)
                    .release(.projected(.eased(.milliseconds(400)))))
            .node
        }
    }
}
