// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A motion layout's parameters of many axes under the hand: the hand moves the axis it drives and no other, and each
// axis comes to rest on its own snaps.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

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
final class LayoutHandParametersTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The bench the layouts are rendered, told their room and turned on.
    private let bench = LayoutBench()

    // MARK: - The hand's axis

    /// THE HAND MOVES ONLY THE AXIS IT DRIVES: the arithmetic is handed the hand's turn beside the zoom as it
    /// stands, and the target passed is named on the turn alone.
    func testTheHandMovesOnlyTheAxisItDrives() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit(turn: 0, zoom: 2))
        let tree = handTree(orbit, handed: handed, range: 0...2)
        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))

        XCTAssertEqual(handed.phases.last, Orbit(turn: 1.4, zoom: 2))
        XCTAssertEqual(orbit.wrappedValue, Orbit(turn: 1, zoom: 2), "the turn passed named, the zoom untouched")
    }

    /// WHILE ANOTHER AXIS TRAVELS THE HAND MOVES ITS OWN: the zoom goes on its way beside it.
    func testWhileAnotherAxisTravelsTheHandMovesItsOwn() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit())
        let tree = handTree(orbit, handed: handed, range: 0...2)
        bench.laid(tree)

        // A unit in 320 milliseconds: a twentieth a frame.
        orbit.wrappedValue.zoom = 2
        bench.frames(4)
        let zoom = try XCTUnwrap(handed.phases.last?.zoom)
        XCTAssertGreaterThan(zoom, 1, "on its way")
        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))

        let shown = try XCTUnwrap(handed.phases.last)
        XCTAssertEqual(shown.turn, 1.4, accuracy: 0.000_1, "the hand's turn")
        XCTAssertEqual(shown.zoom, zoom + 0.1, accuracy: 0.000_1, "beside the zoom, two frames on its way")
    }

    /// THE HAND HOLDS ITS OWN AXIS ALONE: the turn stands under the hand, bound for the snap it passed, and a zoom on
    /// its way stays on it, its lanes untouched.
    func testHoldingTheTurnLeavesTheZoomOnItsWay() throws {
        let orbit = State(wrappedValue: Orbit())
        let tree = handTree(orbit, range: 0...2)
        bench.laid(tree)

        orbit.wrappedValue.zoom = 2
        bench.frames(4)
        let zoom = try XCTUnwrap(bench.journey?.value[1])
        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))

        let journey = try XCTUnwrap(bench.journey)
        XCTAssertEqual(journey.value[0], 1.4, accuracy: 0.000_1, "the turn under the hand")
        XCTAssertEqual(journey.destination[0], 1, "bound for the snap it passed")
        XCTAssertEqual(journey.value[1], zoom + 0.1, accuracy: 0.000_1, "the zoom where it has got to")
        XCTAssertEqual(journey.destination[1], 2, "and still going where it was sent")
    }

    /// PAST ITS RANGE'S END THE HAND MOVES THE RUN LESS AND LESS - a unit past it gives three tenths.
    func testPastItsRangesEndTheHandMovesTheRunLessAndLess() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit(turn: 3, zoom: 1))
        let tree = handTree(orbit, handed: handed, range: 1...3, snaps: .endpoints)
        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-100, 0))

        XCTAssertEqual(handed.phases.last?.turn ?? 0, 3.3, accuracy: 0.001)
    }

    // MARK: - Coming to rest

    /// AN AXIS RESTS ON ITS OWN SNAPS ALONE: the hand lets go of the turn and the turn comes onto its nearest; the
    /// zoom, where the program left it, stays.
    func testLetGoTheAxisRestsOnItsOwnSnapsAndLeavesTheOthers() throws {
        let orbit = State(wrappedValue: Orbit(turn: 0, zoom: 1.3))
        let tree = handTree(orbit, range: 0...2)
        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))
        bench.hand(.ended)

        XCTAssertEqual(try XCTUnwrap(bench.journey).destination, [1, 1.3])
    }

    // MARK: - The bench

    /// A layout of one view whose hand moves the turn, a hundred points a unit, over `range`, resting on `snaps`.
    private func handTree(
        _ orbit: State<Orbit>, handed: Handed? = nil, range: ClosedRange<Double>, snaps: AxisValues = .every(1)
    ) -> () -> Node {
        {
            MotionLayout([1], parameters: orbit.traveling(.eased(.milliseconds(320), curve: .linear))) { Text("\($0)") } placements: { _, phase in
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
