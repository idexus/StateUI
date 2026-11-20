// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The numbers of a motion layout's parameters under the hand: how far it takes each, where each rests, whether it
// comes round - one input moving one or several.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A table panned across with a sky behind it moving slower, how near it stands and how far it is turned - and a note
/// that is no axis.
private struct Table: LayoutParameters {
    var x = 0.0
    var sky = 0.0
    var zoom = 1.0
    var turn = 0.0
    var note = 0.0

    static var axes: [WritableKeyPath<Table, Double>] { [\.x, \.sky, \.zoom, \.turn] }
}

/// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
private final class Handed {
    var tables: [Table] = []
}

@MainActor
final class LayoutHandAxisTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// A layout of one view over `table`, traveling under `motion`, its axes as `declared` says.
    private func tree(
        _ table: State<Table>, _ handed: Handed, motion: Motion = .eased(.milliseconds(160), curve: .linear),
        _ declared: @escaping (MotionLayout<[Int], Int, Table>) -> MotionLayout<[Int], Int, Table>
    ) -> () -> Node {
        {
            declared(
                MotionLayout([0], parameters: table.traveling(motion)) { Text("\($0)") } placements: { _, table in
                    handed.tables.append(table)
                    return [Placement(Rect(0, 0, 40, 40))]
                }
            )
            .node
        }
    }

    // MARK: - An axis with no snaps

    /// AN AXIS WITH NO SNAPS IS GOING WHERE THE HAND HOLDS IT - inside its range - and rests where the hand leaves
    /// it: the state follows the hand as a slider's follows its thumb.
    func testAnAxisWithNoSnapsRestsWhereTheHandLeavesIt() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) { $0.interaction(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3).release(.projected(.eased(.milliseconds(400))))) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))
        XCTAssertEqual(handed.tables.last?.x ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(table.wrappedValue.x, 1.4, accuracy: 0.001, "going where the hand holds it")

        bench.hand(.changed, moved: Point(-200, 0))
        XCTAssertGreaterThan(handed.tables.last?.x ?? 0, 3, "past the end under the hand")
        XCTAssertEqual(table.wrappedValue.x, 3, "going no farther than its range")

        bench.hand(.changed, moved: Point(200, 0))
        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.x, 1.4, accuracy: 0.001)
        XCTAssertEqual(handed.tables.last?.x ?? 0, 1.4, accuracy: 0.001)
    }

    /// LET GO MOVING, AN AXIS WITH NO SNAPS GOES ON AS THE HAND WENT: no frame after the lift carries it farther
    /// than a frame of the hand did - a springy layout motion or none - and it slows to where its throw ends.
    func testLetGoMovingAnAxisWithNoSnapsGoesOnAsTheHandWent() {
        for motion in [Motion.spring(response: .milliseconds(420), damping: 0.82), .eased(.milliseconds(300))] {
            Renderer.shared.clearStates()
            let (table, handed) = (State(wrappedValue: Table()), Handed())
            let built = tree(table, handed, motion: motion) {
                $0.interaction(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3).release(.projected(.eased(.milliseconds(400)))))
            }
            bench.laid(built)

            // Two units a second: 3.2 points, three hundredths of a unit, a frame.
            bench.hand(.began)
            for _ in 0..<10 { bench.hand(.changed, moved: Point(-3.2, 0)) }
            bench.hand(.ended, velocity: Point(-200, 0))

            var shown = [handed.tables.last?.x ?? 0]
            for _ in 0..<40 {
                bench.cycle()
                shown.append(handed.tables.last?.x ?? 0)
            }
            let leaps = zip(shown, shown.dropFirst()).map { $1 - $0 }

            XCTAssertLessThanOrEqual(leaps.max() ?? 0, 0.032 * 1.05, "no leap ahead of the hand under \(motion)")
            XCTAssertGreaterThanOrEqual(leaps.min() ?? 0, -0.000_1, "nor back")
            XCTAssertEqual(table.wrappedValue.x, 0.32 + 0.8 / 3, accuracy: 0.001, "where the throw ends")
        }
    }

    /// LET GO, EVERY AXIS IS NAMED WHERE IT RESTS AND THE RUN GOES ON THERE AS ONE JOURNEY FROM WHERE THE HANDS LEFT
    /// IT: the host walks it from there, no leap back at the lift, each axis setting out at its hand's speed - one let
    /// go still where it rests standing still.
    func testLetGoEveryAxisIsNamedWhereItRestsAndOneJourneyGoesOnFromTheHands() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed, motion: .spring(response: .milliseconds(420), damping: 0.82)) {
            $0.interaction(.simultaneous([
                .value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100)))
                    .reversed(true).range(0...3),
                .value(table.projectedValue, axis: \.turn, input: .translation(.vertical, unit: .points(100)))
                    .reversed(true).range(0...3),
            ]).release(.projected(.eased(.milliseconds(400)))))
        }
        bench.laid(built)

        // Across, and a little down: thrown across, let go still down.
        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, -30))
        bench.hand(.ended, velocity: Point(-300, -10))

        // The lanes are the axes in their order: x the first, turn the fourth.
        let lanes = try XCTUnwrap(bench.journey)
        XCTAssertEqual(lanes.value[0], 1.4, accuracy: 0.000_1, "from where the hand left it")
        XCTAssertEqual(lanes.destination[0], table.wrappedValue.x, "to where it rests")
        XCTAssertGreaterThan(lanes.destination[0], 1.4)
        XCTAssertEqual(lanes.velocity[0], 3, accuracy: 0.000_1, "at the hand's speed: 300 points a second, 100 a unit")
        XCTAssertEqual(lanes.value[3], 0.3, accuracy: 0.000_1, "the axis let go still where it was let go")
        XCTAssertEqual(lanes.destination[3], 0.3, accuracy: 0.000_1, "and resting there")
        XCTAssertEqual(lanes.velocity[3], 0, "standing still")
        XCTAssertEqual(handed.tables.last?.turn ?? 0, 0.3, accuracy: 0.000_1, "shown there")
    }

    /// PAST ITS END THE AXIS GIVES LESS AND LESS, and let go it comes back onto the end.
    func testPastItsEndTheAxisComesBackOntoTheEnd() {
        let (table, handed) = (State(wrappedValue: Table(x: 3)), Handed())
        let built = tree(table, handed) { $0.interaction(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3).release(.projected(.eased(.milliseconds(400))))) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-100, 0))
        XCTAssertEqual(handed.tables.last?.x ?? 0, 3.3, accuracy: 0.001, "a unit past gives three tenths")

        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.x, 3)
        XCTAssertEqual(handed.tables.last?.x ?? 0, 3, accuracy: 0.000_1)
    }

    /// A THROW GOES ON TO WHERE IT WOULD END, and no farther than the range's end.
    func testAThrowGoesOnToWhereItWouldEnd() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) { $0.interaction(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3).release(.projected(.eased(.milliseconds(400))))) }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-20, 0))
        // A unit a second, for 400 ms over the cubic's steepness at its start, three: two fifteenths on.
        bench.hand(.ended, velocity: Point(-100, 0))
        bench.frames(60)
        XCTAssertEqual(table.wrappedValue.x, 0.2 + 0.4 / 3, accuracy: 0.001)

        bench.hand(.began)
        bench.hand(.ended, velocity: Point(-3_000, 0))
        bench.frames(60)
        XCTAssertEqual(table.wrappedValue.x, 3, "held to the end")
    }

    /// LIMITS ALONE: let go anywhere between, the axis comes onto the nearer end.
    func testAnAxisSnappingToItsLimitsRestsOnTheNearerEnd() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) {
            $0.interaction(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...3).snaps(.endpoints).release(.projected(.eased(.milliseconds(400)))))
        }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))
        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.x, 0)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-160, 0))
        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.x, 3)
    }

    // MARK: - Coming round

    /// AN AXIS THAT COMES ROUND HAS NO END: the hand moves it on past its range's length, and with no snaps it
    /// rests there.
    func testAnAxisThatComesRoundHasNoEnd() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) {
            $0.interaction(.value(table.projectedValue, axis: \.turn, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...1).periodic(true).release(.projected(.eased(.milliseconds(400)))))
        }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-250, 0))
        XCTAssertEqual(handed.tables.last?.turn ?? 0, 2.5, accuracy: 0.001, "no end to give less past")

        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.turn, 2.5, accuracy: 0.001)
    }

    /// SNAPS COME ROUND: a quarter a snap, let go at nine tenths the axis comes onto one - the first again, a turn
    /// on.
    func testSnapsComeRoundATurnOn() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) {
            $0.interaction(.value(table.projectedValue, axis: \.turn, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...1).snaps(.every(0.25)).periodic(true).release(.projected(.eased(.milliseconds(400)))))
        }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-90, 0))
        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.turn, 1)
    }

    // MARK: - One input, several axes

    /// ONE INPUT MOVES SEVERAL AXES, each by its own unit and resting its own way: the hand moves the table and, half
    /// as fast, the sky - one way, heard along the layout.
    func testOneInputMovesSeveralAxes() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) {
            $0.interaction(.simultaneous([
                .value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100)))
                    .reversed(true).range(0...3).snaps(.every(1)),
                .value(table.projectedValue, axis: \.sky, input: .translation(.horizontal, unit: .points(200)))
                    .reversed(true).range(0...3),
            ]).release(.projected(.eased(.milliseconds(400)))))
        }
        bench.laid(built)
        XCTAssertEqual(bench.layout?.handWay, .horizontal, "one way, however many numbers it moves")

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-140, 0))
        XCTAssertEqual(handed.tables.last?.x ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(handed.tables.last?.sky ?? 0, 0.7, accuracy: 0.001)

        bench.hand(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.x, 1, "onto its snap")
        XCTAssertEqual(table.wrappedValue.sky, 0.7, accuracy: 0.001, "where the hand left it")
    }

    /// TWO FINGERS ON A MAGNIFICATION WITH NO SNAPS rest where they leave it, and past its end come back onto it.
    func testAMagnificationWithNoSnapsRestsWhereTheFingersLeaveIt() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) { $0.interaction(.value(table.projectedValue, axis: \.zoom, input: .magnification).range(0.5...2).release(.projected(.eased(.milliseconds(400))))) }
        bench.laid(built)

        bench.pinch(.began)
        bench.pinch(.changed, scale: 1.5)
        bench.pinch(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.zoom, 1.5, accuracy: 0.000_1)

        bench.pinch(.began)
        bench.pinch(.changed, scale: 2)
        XCTAssertGreaterThan(handed.tables.last?.zoom ?? 0, 2, "past the end")
        bench.pinch(.ended)
        bench.frames()
        XCTAssertEqual(table.wrappedValue.zoom, 2, accuracy: 0.000_1)
    }

    // MARK: - What is wrong

    /// A VALUE GIVEN NO RANGE HAS NO END: the hand moves it as far as it goes, with nothing to come back onto.
    func testAValueGivenNoRangeHasNoEnd() {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let built = tree(table, handed) {
            $0.interaction(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(100))).release(.stay))
        }
        bench.laid(built)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(730, 0))
        bench.hand(.ended)
        bench.frames(10)

        XCTAssertEqual(table.wrappedValue.x, 7.3, accuracy: 0.000_1, "to the right the value grows, unless reversed")
    }

}
