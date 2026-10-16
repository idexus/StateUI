// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout engine's phase of many axes: how it lies on the host's lanes, which axis a hand moves, and where each
// axis comes to rest.

import XCTest

@_spi(Host) @testable import StateUI

/// A phase of two axes: how far a ring is turned, and how near it stands.
private struct Orbit: LayoutPhase {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
}

/// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
private final class Handed {
    var phases: [Orbit] = []
}

@MainActor
final class LayoutPhaseTests: XCTestCase {
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
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .phase(orbit.projectedValue)
                .node
        }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

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
            LayoutEngine([1]) { Text("\($0)") } placements: { _, phase in
                handed.phases.append(phase)
                return [Placement(Rect(0, 0, 10, 10))]
            }
            .phase(orbit.projectedValue)
            .node
        }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        orbit.wrappedValue = Orbit(turn: 1, zoom: 2)
        bench.cycle()
        moved(worn, to: [0.5, 1.5], mask: 0b11)
        bench.cycle()

        XCTAssertEqual(handed.phases.last, Orbit(turn: 0.5, zoom: 1.5))
    }

    // MARK: - The hand's axis

    /// THE HAND MOVES ONLY THE AXIS IT DRIVES: the arithmetic is handed the hand's turn beside the zoom as it
    /// stands, and the target passed is named on the turn alone.
    func testTheHandMovesOnlyTheAxisItDrives() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit(turn: 0, zoom: 2))
        let renders = Renders()
        let tree = handTree(orbit, handed: handed) { $0.snap(\.turn, to: [0, 1, 2]) }
        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-140, 0))

        XCTAssertEqual(handed.phases.last, Orbit(turn: 1.4, zoom: 2))
        XCTAssertEqual(orbit.wrappedValue, Orbit(turn: 1, zoom: 2), "the turn passed named, the zoom untouched")
    }

    /// WHILE ANOTHER AXIS TRAVELS THE HAND MOVES ITS OWN: the zoom goes on its way beside it.
    func testWhileAnotherAxisTravelsTheHandMovesItsOwn() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit())
        let renders = Renders()
        let tree = handTree(orbit, handed: handed) { $0.snap(\.turn, to: [0, 1, 2]) }
        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        orbit.wrappedValue.zoom = 2
        bench.cycle()
        moved(worn, to: [0, 1.5], mask: 0b11)
        bench.cycle()
        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-140, 0))

        XCTAssertEqual(handed.phases.last, Orbit(turn: 1.4, zoom: 1.5), "the hand's turn beside the zoom on its way")
    }

    /// THE HAND NAMES ITS OWN AXIS ALONE: a zoom on its way stays on it, its lanes untouched.
    func testNamingTheTurnLeavesTheZoomOnItsWay() throws {
        let orbit = State(wrappedValue: Orbit())
        let renders = Renders()
        let tree = handTree(orbit) { $0.snap(\.turn, to: [0, 1, 2]) }
        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        orbit.wrappedValue.zoom = 2
        bench.cycle()
        moved(worn, to: [0, 1.5], mask: 0b11)
        bench.cycle()
        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-140, 0))

        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Orbit>.self))
        XCTAssertEqual(journey.value, Orbit(turn: 1, zoom: 1.5), "the turn named, the zoom where it has got to")
        XCTAssertEqual(journey.destination, Orbit(turn: 1, zoom: 2), "and still going where it was sent")
    }

    /// PAST ITS AXIS'S LAST TARGET THE HAND MOVES THE RUN LESS AND LESS - a unit past it gives three tenths: the
    /// targets of its own axis are its ends.
    func testTheHandsEndsAreTheTargetsOfItsAxis() throws {
        let handed = Handed()
        let orbit = State(wrappedValue: Orbit(turn: 3, zoom: 1))
        let renders = Renders()
        let tree = handTree(orbit, handed: handed) { $0.snap(\.turn, to: [1, 3]) }
        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-100, 0))

        XCTAssertEqual(handed.phases.last?.turn ?? 0, 3.3, accuracy: 0.001)
    }

    /// A HAND NEEDS TARGETS ON ITS OWN AXIS: one driving an axis no target names hears no hand and says why.
    func testAHandWithNoTargetsOnItsAxisMovesNothing() throws {
        let patch = Renders().render(
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [] }
                .phase(State(wrappedValue: Orbit()).projectedValue)
                .input(.scroll(.vertical, pointsPerUnit: 50), drives: \.zoom)
                .snap(\.turn, to: [0, 1])
                .node)

        XCTAssertNil(try XCTUnwrap(patch.first(.layoutEngine)).events?[.handMoved])
        XCTAssertTrue(hasComplained("given a scroll but no snap targets on the axis it drives"))
    }

    // MARK: - Coming to rest

    /// AN AXIS WITH TARGETS OF ITS OWN RESTS ON THEM ALONE: the hand lets go of the turn and the turn comes onto its
    /// nearest; the zoom, where the program left it between its own targets, stays.
    func testLetGoTheAxisRestsOnItsOwnTargetsAndLeavesTheOthers() throws {
        let orbit = State(wrappedValue: Orbit(turn: 0, zoom: 1.3))
        let renders = Renders()
        let tree = handTree(orbit) { $0.snap(\.turn, to: [0, 1, 2]).snap(\.zoom, to: [1, 2]) }
        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-140, 0))
        bench.hand(renders, tree, .ended)

        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Orbit>.self))
        XCTAssertEqual(journey.destination, Orbit(turn: 1, zoom: 1.3))
    }

    /// WHOLE STATES ARE THE COMBINATIONS THE RUN MAY REST AT: the hand passing names its own axis alone, and letting
    /// go sends every axis to the nearest whole state.
    func testWholeStatesAreTheCombinationsTheRunMayRestAt() throws {
        let targets = [Orbit(turn: 0, zoom: 1), Orbit(turn: 1, zoom: 2), Orbit(turn: 2, zoom: 2)]
        let orbit = State(wrappedValue: Orbit(turn: 0, zoom: 1))
        let renders = Renders()
        let tree = handTree(orbit) { $0.snapTargets(targets) }
        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-120, 0))
        XCTAssertEqual(orbit.wrappedValue, Orbit(turn: 1, zoom: 1), "the turn passed named, nothing else")

        bench.hand(renders, tree, .ended)
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Orbit>.self)).destination, Orbit(turn: 1, zoom: 2),
                       "the nearest whole state, its zoom with it")
    }

    // MARK: - The bench

    /// A layout of one view whose hand drives the turn, a hundred points a unit, its targets given by `targets`.
    private func handTree(
        _ orbit: State<Orbit>, handed: Handed? = nil,
        _ targets: @escaping (LayoutEngine<[Int], Int, Orbit>) -> LayoutEngine<[Int], Int, Orbit>
    ) -> () -> Node {
        {
            targets(
                LayoutEngine([1]) { Text("\($0)") } placements: { _, phase in
                    handed?.phases.append(phase)
                    return [Placement(Rect(0, 0, 10, 10))]
                }
                .phase(orbit.projectedValue)
                .input(.scroll(.horizontal, pointsPerUnit: 100), drives: \.turn)
            )
            .node
        }
    }
}
