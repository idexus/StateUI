// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout engine's axis declared whole: its range, where it rests, whether it comes round, and the input that moves
// it - one an axis, one input to several.

import XCTest

@_spi(Host) @testable import StateUI

/// A table panned across with a sky behind it moving slower, how near it stands and how far it is turned - and a note
/// that is no axis.
private struct Table: LayoutPhase {
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
final class LayoutAxisTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// A layout of one view over `table`, travelling under `motion`, its axes as `declared` says.
    private func tree(
        _ table: State<Table>, _ handed: Handed, motion: Motion = .eased(.milliseconds(160), .linear),
        _ declared: @escaping (LayoutEngine<[Int], Int, Table>) -> LayoutEngine<[Int], Int, Table>
    ) -> () -> Node {
        {
            declared(
                LayoutEngine([0]) { Text("\($0)") } placements: { _, table in
                    handed.tables.append(table)
                    return [Placement(Rect(0, 0, 40, 40))]
                }
                .phase(table.projectedValue)
                .motion(motion)
            )
            .node
        }
    }

    private func frames(_ count: Int = 30) {
        for _ in 0..<count { bench.cycle() }
    }

    // MARK: - Snaps

    /// THE SNAPS ARE THE PLACES GIVEN AND THE RANGE'S ENDS - the upper end the lower one a turn on where the axis
    /// comes round.
    func testTheSnapsAreThePlacesGivenAndTheEnds() {
        XCTAssertEqual(([1, 2] as LayoutPlaces).values(in: 0...3, wraps: false), [0, 1, 2, 3])
        XCTAssertEqual(LayoutPlaces.limits.values(in: 0...3, wraps: false), [0, 3])
        XCTAssertEqual(LayoutPlaces.every(1).values(in: 0...3, wraps: false), [0, 1, 2, 3])
        XCTAssertEqual(LayoutPlaces.every(1).values(in: 0...2.5, wraps: false), [0, 1, 2, 2.5])
        XCTAssertEqual(LayoutPlaces.every(0.25).values(in: 0...1, wraps: true), [0, 0.25, 0.5, 0.75])
        XCTAssertEqual(LayoutPlaces.at([-1, 0.5, 4]).values(in: 0...3, wraps: false), [0, 0.5, 3], "outside, left out")
        XCTAssertEqual(LayoutPlaces.every(0.1).values(in: 0...1, wraps: false).count, 11, "none a rounding short of 1")
    }

    // MARK: - An axis with no snaps

    /// AN AXIS WITH NO SNAPS RESTS WHERE THE HAND LEAVES IT, and is named nothing while the hand holds it.
    func testAnAxisWithNoSnapsRestsWhereTheHandLeavesIt() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) { $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-140, 0))
        XCTAssertEqual(handed.tables.last?.x ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(table.wrappedValue.x, 0, "nothing named under the hand")

        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.x, 1.4, accuracy: 0.001)
        XCTAssertEqual(handed.tables.last?.x ?? 0, 1.4, accuracy: 0.001)
    }

    /// LET GO MOVING, AN AXIS WITH NO SNAPS GOES ON AS THE HAND WENT: no frame after the lift carries it farther
    /// than a frame of the hand did - a springy layout motion or none - and it slows to where its throw ends.
    func testLetGoMovingAnAxisWithNoSnapsGoesOnAsTheHandWent() {
        for motion in [Motion.spring(response: .milliseconds(420), damping: 0.82), .eased(.milliseconds(300), .cubicOut)] {
            Renderer.shared.clearStates()
            let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
            let built = tree(table, handed, motion: motion) {
                $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3)
            }
            _ = bench.laid(renders, built)

            // Two units a second: 3.2 points, three hundredths of a unit, a frame.
            bench.hand(renders, built, .began)
            for _ in 0..<10 { bench.hand(renders, built, .changed, moved: Point(-3.2, 0)) }
            bench.hand(renders, built, .ended, speed: Point(-200, 0))

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

    /// LET GO, EVERY AXIS IS NAMED WHERE IT RESTS AND THE HOST IS SENT ON NO JOURNEY: a host walking one would carry
    /// an axis the hand held - not named while it held it - from where the host last had it, a leap back at the lift.
    func testLetGoEveryAxisIsNamedWhereItRestsAndNoJourneyIsBooked() throws {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed, motion: .spring(response: .milliseconds(420), damping: 0.82)) {
            $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3)
                .axis(\.turn, input: .scroll(.vertical, pointsPerUnit: 100), range: 0...3)
        }
        let worn = try XCTUnwrap(bench.laid(renders, built).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        // Across, and a little down: thrown across, let go still down.
        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-140, -30))
        bench.hand(renders, built, .ended, speed: Point(-300, -10))

        let lanes = try XCTUnwrap(standing(worn, as: JourneyLanes<Table>.self))
        XCTAssertEqual(lanes.completion, 0, "no journey for the host to walk")
        XCTAssertEqual(lanes.value, lanes.destination)
        XCTAssertEqual(lanes.value.turn, 0.3, accuracy: 0.000_1, "the axis let go still, named where it was let go")
        XCTAssertEqual(handed.tables.last?.turn ?? 0, 0.3, accuracy: 0.000_1, "and shown there")
    }

    /// PAST ITS END THE AXIS GIVES LESS AND LESS, and let go it comes back onto the end.
    func testPastItsEndTheAxisComesBackOntoTheEnd() {
        let (table, handed, renders) = (State(wrappedValue: Table(x: 3)), Handed(), Renders())
        let built = tree(table, handed) { $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-100, 0))
        XCTAssertEqual(handed.tables.last?.x ?? 0, 3.3, accuracy: 0.001, "a unit past gives three tenths")

        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.x, 3)
        XCTAssertEqual(handed.tables.last?.x ?? 0, 3, accuracy: 0.000_1)
    }

    /// A THROW GOES ON TO WHERE IT WOULD END, and no farther than the range's end.
    func testAThrowGoesOnToWhereItWouldEnd() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) { $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-20, 0))
        // A unit a second, for 400 ms over the cubic's steepness at its start, three: two fifteenths on.
        bench.hand(renders, built, .ended, speed: Point(-100, 0))
        frames(60)
        XCTAssertEqual(table.wrappedValue.x, 0.2 + 0.4 / 3, accuracy: 0.001)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .ended, speed: Point(-3_000, 0))
        frames(60)
        XCTAssertEqual(table.wrappedValue.x, 3, "held to the end")
    }

    /// LIMITS ALONE: let go anywhere between, the axis comes onto the nearer end.
    func testAnAxisSnappingToItsLimitsRestsOnTheNearerEnd() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) {
            $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3, snaps: .limits)
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-140, 0))
        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.x, 0)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-160, 0))
        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.x, 3)
    }

    // MARK: - Coming round

    /// AN AXIS THAT COMES ROUND HAS NO END: the hand moves it on past its range's length, and with no snaps it
    /// rests there.
    func testAnAxisThatComesRoundHasNoEnd() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) {
            $0.axis(\.turn, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...1, wraps: true)
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-250, 0))
        XCTAssertEqual(handed.tables.last?.turn ?? 0, 2.5, accuracy: 0.001, "no end to give less past")

        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.turn, 2.5, accuracy: 0.001)
    }

    /// SNAPS COME ROUND: a quarter a snap, let go at nine tenths the axis comes onto one - the first again, a turn
    /// on.
    func testSnapsComeRoundATurnOn() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) {
            $0.axis(
                \.turn, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...1, snaps: .every(0.25),
                wraps: true)
        }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-90, 0))
        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.turn, 1)
    }

    // MARK: - One input, several axes

    /// ONE INPUT MOVES SEVERAL AXES, each by its own unit and resting its own way: the hand moves the table and, half
    /// as fast, the sky - one way, heard along the layout.
    func testOneInputMovesSeveralAxes() throws {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) {
            $0.axis(\.x, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3, snaps: .every(1))
                .axis(\.sky, input: .scroll(.horizontal, pointsPerUnit: 200), range: 0...3)
        }
        let layout = try XCTUnwrap(bench.laid(renders, built).patch.first(.layoutEngine))
        XCTAssertEqual(layout.properties[.handAxis], .enumeration(LayoutInput.Axis.horizontal.rawValue))
        XCTAssertNil(layout.properties[.pans])

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-140, 0))
        XCTAssertEqual(handed.tables.last?.x ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(handed.tables.last?.sky ?? 0, 0.7, accuracy: 0.001)

        bench.hand(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.x, 1, "onto its snap")
        XCTAssertEqual(table.wrappedValue.sky, 0.7, accuracy: 0.001, "where the hand left it")
    }

    /// TWO FINGERS ON A MAGNIFICATION WITH NO SNAPS rest where they leave it, and past its end come back onto it.
    func testAMagnificationWithNoSnapsRestsWhereTheFingersLeaveIt() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) { $0.axis(\.zoom, input: .magnification, range: 0.5...2) }
        _ = bench.laid(renders, built)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, scale: 1.5)
        bench.pinch(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.zoom, 1.5, accuracy: 0.000_1)

        bench.pinch(renders, built, .began)
        bench.pinch(renders, built, .changed, scale: 2)
        XCTAssertGreaterThan(handed.tables.last?.zoom ?? 0, 2, "past the end")
        bench.pinch(renders, built, .ended)
        frames()
        XCTAssertEqual(table.wrappedValue.zoom, 2, accuracy: 0.000_1)
    }

    // MARK: - What is wrong

    /// AN AXIS THE PHASE DOES NOT LIST moves nothing, and says why.
    func testAnAxisThePhaseDoesNotListMovesNothing() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let patch = Renders().render(tree(table, handed) {
            $0.axis(\.note, input: .scroll(.horizontal), range: 0...1)
        }())

        XCTAssertNil(try XCTUnwrap(patch.first(.layoutEngine)).events?[.handMoved])
        XCTAssertTrue(hasComplained("an axis its phase's `axes` does not list"))
    }

    /// A MAGNIFICATION'S RANGE STANDS ABOVE NOUGHT: one reaching it moves nothing, and says why.
    func testAMagnificationReachingNoughtMovesNothing() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let patch = Renders().render(tree(table, handed) { $0.axis(\.zoom, input: .magnification, range: 0...2) }())

        XCTAssertNil(try XCTUnwrap(patch.first(.layoutEngine)).properties[.magnifies])
        XCTAssertTrue(hasComplained("a range reaching nought"))
    }

    /// A SWIPE GIVEN NO SNAPS swipes from end to end, and says why.
    func testASwipeGivenNoSnapsSwipesFromEndToEnd() {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let built = tree(table, handed) { $0.axis(\.x, input: .swipe(.horizontal, pointsPerUnit: 100), range: 0...3) }
        _ = bench.laid(renders, built)

        bench.hand(renders, built, .began)
        bench.hand(renders, built, .changed, moved: Point(-40, 0))
        bench.hand(renders, built, .ended, speed: Point(-300, 0))
        frames(60)

        XCTAssertEqual(table.wrappedValue.x, 3)
        XCTAssertTrue(hasComplained("its axis was given none"))
    }
}
