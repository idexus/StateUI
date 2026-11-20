// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A motion layout's axis declared whole: its range, where it rests, whether it comes round, and the input that moves
// it - one an axis, one input to several.

import XCTest

@_spi(Host) @testable import StateUI

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
final class LayoutAxisTests: XCTestCase {
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

    private func frames(_ count: Int = 30) {
        for _ in 0..<count { bench.cycle() }
    }

    // MARK: - Snaps

    /// THE SNAPS ARE THE PLACES GIVEN AND THE RANGE'S ENDS - the upper end the lower one a turn on where the axis
    /// comes round.
    func testTheSnapsAreThePlacesGivenAndTheEnds() {
        XCTAssertEqual(([1, 2] as AxisValues).values(in: 0...3, periodic: false), [0, 1, 2, 3])
        XCTAssertEqual(AxisValues.endpoints.values(in: 0...3, periodic: false), [0, 3])
        XCTAssertEqual(AxisValues.every(1).values(in: 0...3, periodic: false), [0, 1, 2, 3])
        XCTAssertEqual(AxisValues.every(1).values(in: 0...2.5, periodic: false), [0, 1, 2, 2.5])
        XCTAssertEqual(AxisValues.every(0.25).values(in: 0...1, periodic: true), [0, 0.25, 0.5, 0.75])
        XCTAssertEqual(AxisValues.at([-1, 0.5, 4]).values(in: 0...3, periodic: false), [0, 0.5, 3], "outside, left out")
        XCTAssertEqual(AxisValues.every(0.1).values(in: 0...1, periodic: false).count, 11, "none a rounding short of 1")
    }


    // MARK: - What is wrong

    /// AN AXIS THE PARAMETERS DO NOT LIST moves nothing, and says why.
    func testAnAxisTheParametersDoNotListMovesNothing() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let patch = Renders().render(tree(table, handed) {
            $0.interaction(.value(table.projectedValue, axis: \.note, input: .translation(.horizontal, unit: .frontItem)).reversed(true).range(0...1).release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
        }())

        XCTAssertTrue(try XCTUnwrap(patch.first(.motionLayout)).moved.isEmpty)
        XCTAssertTrue(hasComplained("a number its state's `axes` do not list"))
    }

    /// AN AXIS MAPPING NOTHING SAYS SO: with no keyframes and no segments the declaration changes nothing.
    func testAnAxisMappingNothingSaysSo() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        _ = Renders().render(tree(table, handed) { $0.axis(\.x, range: 0...1) }())
        XCTAssertTrue(hasComplained("no keyframes and no segments"))
    }

    /// AN INTERACTION THAT DOES NOT STAND MOVES NOTHING, and says why: coming round over no range, the ends of no
    /// range, points a unit not above nought, and what each value says for itself said of several at once.
    func testAnInteractionThatDoesNotStandMovesNothing() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let hand = InteractionInput.translation(.horizontal, unit: .points(100))
        func heard(_ interaction: Interaction) throws -> Bool {
            let patch = Renders().render(tree(table, handed) { $0.interaction(interaction) }())
            return try !XCTUnwrap(patch.first(.motionLayout)).moved.isEmpty
        }

        XCTAssertFalse(try heard(.value(table.projectedValue, axis: \.x, input: hand).periodic(true)))
        XCTAssertTrue(hasComplained("told to come round with no range"))

        XCTAssertFalse(try heard(.value(table.projectedValue, axis: \.x, input: hand).snaps(.endpoints)))
        XCTAssertTrue(hasComplained("the ends of a range, and no range"))

        _ = try heard(.value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .points(0))))
        XCTAssertTrue(hasComplained("points a unit that are not above nought"))

        XCTAssertTrue(try heard(.simultaneous([.value(table.projectedValue, axis: \.x, input: hand)]).range(0...1)))
        XCTAssertTrue(hasComplained("several values at once was given `range`"))
    }

    /// A MAGNIFICATION'S RANGE STANDS ABOVE NOUGHT: one reaching it moves nothing, and says why.
    func testAMagnificationReachingNoughtMovesNothing() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let patch = Renders().render(tree(table, handed) { $0.interaction(.value(table.projectedValue, axis: \.zoom, input: .magnification).range(0...2).release(.projected(.eased(.milliseconds(400), curve: .cubicOut)))) }())

        XCTAssertTrue(try XCTUnwrap(patch.first(.motionLayout)).moved.isEmpty)
        XCTAssertTrue(hasComplained("a range reaching nought"))
    }

    /// A SWIPE GIVEN NO SNAPS MOVES NOTHING, and says why: a swipe goes a snap a hand.
    func testASwipeGivenNoSnapsMovesNothing() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let patch = Renders().render(tree(table, handed) {
            $0.interaction(
                .value(table.projectedValue, axis: \.x, input: .swipe(.horizontal, unit: .points(100))).range(0...3))
        }())

        XCTAssertTrue(try XCTUnwrap(patch.first(.motionLayout)).moved.isEmpty)
        XCTAssertTrue(hasComplained("was given no snaps"))
    }

    // MARK: - What the host is handed

    /// SNAPS WITH NO RANGE STAND AS WRITTEN: every multiple of a step, worked out by the host and never listed; a
    /// list as it is; and between the ends of a range, the ends with them.
    func testSnapsWithNoRangeStandAsWritten() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let hand = InteractionInput.translation(.horizontal, unit: .points(100))
        func snaps(_ interaction: Interaction) throws -> HostInteractionSnaps? {
            let patch = Renders().render(tree(table, handed) { $0.interaction(interaction) }())
            return try XCTUnwrap(XCTUnwrap(patch.first(.motionLayout)).moved.first).snaps
        }

        XCTAssertEqual(try snaps(.value(table.projectedValue, axis: \.x, input: hand).snaps(.every(0.5))), .every(0.5))
        XCTAssertEqual(try snaps(.value(table.projectedValue, axis: \.x, input: hand).snaps([2, 1, 2])), .at([1, 2]))
        XCTAssertEqual(
            try snaps(.value(table.projectedValue, axis: \.x, input: hand).range(0...3).snaps([1, 2])),
            .at([0, 1, 2, 3]))
        XCTAssertNil(try snaps(.value(table.projectedValue, axis: \.x, input: hand).range(0...3)), "anywhere")
    }

    /// EACH VALUE IS HANDED AS ITS STATE'S LANE: the state's number, the axis's place among its numbers, what moves
    /// it, its ends, which way it grows, how it goes on let go and what a write of the program does to it.
    func testEachValueIsHandedAsItsStatesLane() throws {
        let (table, handed) = (State(wrappedValue: Table()), Handed())
        let release = InteractionRelease.nearest(.eased(.milliseconds(200)))
        let patch = Renders().render(tree(table, handed) {
            $0.interaction(.simultaneous([
                .value(table.projectedValue, axis: \.x, input: .swipe(.vertical, unit: .containerLength))
                    .reversed(true).range(0...3).snaps(.every(1)),
                .value(table.projectedValue, axis: \.turn, input: .rotation(degreesPerUnit: 90))
                    .range(0...4).periodic(true),
            ]).release(release).programWrites(.deferLatest))
        }())
        let layout = try XCTUnwrap(patch.first(.motionLayout))
        let state = try XCTUnwrap(layout.driven?[.parameters]?.state)

        XCTAssertEqual(layout.moved, [
            HostInteractionValue(
                state: state, lane: 0, input: .translation(.vertical, unit: .containerLength, swipes: true), low: 0,
                high: 3, snaps: .at([0, 1, 2, 3]), reversed: true, release: release, programWrites: .deferLatest),
            HostInteractionValue(
                state: state, lane: 3, input: .rotation(degreesPerUnit: 90), low: 0, high: 4, periodic: true,
                release: release, programWrites: .deferLatest),
        ])
    }

    /// A PROGRAM DESCRIBED AGAIN ALIKE IS NOT TOLD AGAIN, one that changed is, and one said no longer is cleared.
    func testAProgramIsToldWhenItChanges() throws {
        let (table, handed, renders) = (State(wrappedValue: Table()), Handed(), Renders())
        let hand = InteractionInput.translation(.horizontal, unit: .points(100))
        var range = 0.0...3.0
        var moves = true
        let built = tree(table, handed) {
            $0.interaction(moves ? .value(table.projectedValue, axis: \.x, input: hand).range(range) : nil)
        }

        XCTAssertFalse(try XCTUnwrap(renders.render(built()).first(.motionLayout)).moved.isEmpty)
        XCTAssertNil(renders.render(built()).first(.motionLayout)?.interaction, "alike: nothing to tell")

        range = 0...5
        XCTAssertEqual(renders.render(built()).first(.motionLayout)?.moved.first?.high, 5)

        moves = false
        XCTAssertEqual(renders.render(built()).first(.motionLayout)?.interaction, .clear)
    }

    /// One layout of one view, moved as `interaction` says.
    private func moved(_ dial: State<Table>, _ interaction: Interaction) -> MotionLayout<[Int], Int, Table> {
        MotionLayout([0], parameters: dial.projectedValue) { Text("\($0)") } placements: { _, _ in
            [Placement(Rect(0, 0, 40, 40))]
        }
        .interaction(interaction)
    }

    /// AN INTERACTION SAID AGAIN TAKES THE OTHER'S PLACE: one declaration says the whole of it.
    func testAnInteractionSaidAgainTakesTheOthersPlace() throws {
        let dial = State(wrappedValue: Table())
        let layout = moved(
            dial, .value(dial.projectedValue, axis: \.zoom, input: .translation(.horizontal, unit: .frontItem)).range(1...2))
            .interaction(.value(dial.projectedValue, axis: \.zoom, input: .magnification).range(1...2))

        let element = try XCTUnwrap(Renders().settled(layout.node).first(.motionLayout))
        XCTAssertEqual(element.moved.map(\.input), [.magnification], "the hand's place taken")
    }

    /// TWO MOVING ONE NUMBER ARE REFUSED TOGETHER: neither is the one the author meant, and it is said.
    func testTwoMovingOneNumberAreRefusedTogether() throws {
        let dial = State(wrappedValue: Table())
        let layout = moved(dial, .simultaneous([
            .value(dial.projectedValue, axis: \.zoom, input: .translation(.horizontal, unit: .frontItem)).range(1...2),
            .value(dial.projectedValue, axis: \.zoom, input: .magnification).range(1...2),
            .value(dial.projectedValue, axis: \.turn, input: .rotation()).range(0...1),
        ]))

        let element = try XCTUnwrap(Renders().settled(layout.node).first(.motionLayout))
        XCTAssertEqual(element.moved.map(\.input), [.rotation(degreesPerUnit: 360)], "the number moved once stands")
        XCTAssertTrue(hasComplained("An interaction moves one number twice"))
    }

    /// A VALUE OF ANOTHER STATE THAN THE LAYOUT'S PARAMETERS IS MOVED AS ON ANY VIEW: the hand over the layout holds
    /// it by its own state's channel, beside the values of the parameters.
    func testAValueOfAnotherStateIsMovedAsOnAnyView() throws {
        let (table, handed, other) = (State(wrappedValue: Table()), Handed(), State(wrappedValue: 0.0))
        let patch = Renders().render(tree(table, handed) {
            $0.interaction(.simultaneous([
                .value(table.projectedValue, axis: \.x, input: .translation(.horizontal, unit: .frontItem)).range(0...3),
                .value(other.projectedValue, input: .translation(.vertical)),
            ]))
        }())
        let layout = try XCTUnwrap(patch.first(.motionLayout))
        let parameters = try XCTUnwrap(layout.driven?[.parameters]?.state)

        XCTAssertEqual(layout.moved.map(\.state), [parameters, try XCTUnwrap(other.storage.image?.number)])
        guard case .replace(let followed)? = layout.followed else { return XCTFail("the other state is not followed") }
        XCTAssertEqual(followed.map(\.state), [try XCTUnwrap(other.storage.image?.number)], "the other state alone")
    }
}
