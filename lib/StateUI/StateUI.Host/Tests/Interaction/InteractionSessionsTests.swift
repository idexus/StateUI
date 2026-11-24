// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A ring turned across and tilted down.
private struct Orbit: LayoutParameters {
    var turn = 0.0
    var tilt = 0.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.tilt] }
}

/// The hands holding numbers of states: one hand a number across every view, a write of the program meeting a hand
/// by the hand's policy, a program described again leaving what it still moves under the hand, and a view that
/// leaves letting go.
@MainActor
final class InteractionSessionsTests: XCTestCase {
    private let bench = LayoutBench()
    private let linear = Motion.eased(.milliseconds(320), curve: .linear)

    /// One view over `orbit`, its hand moving the turn across - and the tilt down, where `tilts` - a hundred
    /// points a unit, resting on each whole one.
    private func layout(
        _ orbit: State<Orbit>, tilts: Bool = true, policy: InteractionProgramWrites = .interrupt
    ) -> MotionLayout<[Int], Int, Orbit> {
        let moved = orbit.traveling(linear)
        var values = [
            Interaction.value(moved, axis: \.turn, input: .translation(.horizontal, unit: .points(100)))
                .range(0...4).snaps(.every(1)),
        ]
        if tilts {
            values.append(
                Interaction.value(moved, axis: \.tilt, input: .translation(.vertical, unit: .points(100)))
                    .range(0...4).snaps(.every(1)))
        }
        return MotionLayout([0], parameters: moved) { Text("\($0)") } placements: { _, _ in
            [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
        }
        .interaction(.simultaneous(values).release(.nearest(linear)).programWrites(policy))
    }

    /// ONE HAND A NUMBER, across every view: a second view's hand on a number another holds moves nothing of it,
    /// and takes it once the first lets go.
    func testOneHandANumberAcrossEveryView() throws {
        let orbit = State(wrappedValue: Orbit())
        bench.laid { ZStack { self.layout(orbit); self.layout(orbit) }.node }
        let (first, second) = (try XCTUnwrap(bench.layouts.first), try XCTUnwrap(bench.layouts.last))
        XCTAssertFalse(first === second)
        let runtime = try XCTUnwrap(bench.runtime)

        bench.hand(.began, on: first)
        bench.hand(.changed, moved: Point(x: 40, y: 0), on: first)
        bench.hand(.began, on: second)
        bench.hand(.changed, moved: Point(x: 200, y: 0), on: second)
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 0.4, accuracy: 0.000_1, "the first hand's, alone")
        XCTAssertTrue(runtime.interactions.holds(first))
        XCTAssertFalse(runtime.interactions.holds(second))

        bench.hand(.ended, on: second)
        bench.hand(.ended, on: first)
        bench.frames(30)
        bench.hand(.began, on: second)
        bench.hand(.changed, moved: Point(x: 140, y: 0), on: second)
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 1.4, accuracy: 0.000_1, "let go, the second takes it")
    }

    /// A WRITE OF THE PROGRAM TAKES THE NUMBER IT WRITES FROM THE HAND, unless the hand waits: that number travels
    /// where the program sent it from under the hand, and what the gesture says until it ends moves it no more -
    /// the next gesture moves it again - while the gesture holds the other number on.
    func testAWriteOfTheProgramTakesTheNumberItWritesFromTheHand() throws {
        let orbit = State(wrappedValue: Orbit())
        bench.laid { self.layout(orbit).node }
        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: 140, y: 60))
        orbit.wrappedValue.turn = 4
        bench.cycle()
        XCTAssertTrue(runtime.interactions.holds(layout), "the hand holds the tilt on")

        bench.hand(.changed, moved: Point(x: -300, y: 100))
        let going = try XCTUnwrap(bench.journey)
        XCTAssertGreaterThan(going.value[0], 1.4, "on its way from under the hand to where the program sent it")
        XCTAssertEqual(going.destination[0], 4, "the turn the program's")
        XCTAssertEqual(going.value[1], 1.6, accuracy: 0.000_1, "the tilt under the hand")

        bench.hand(.ended)
        bench.frames(80)
        XCTAssertEqual(orbit.wrappedValue, Orbit(turn: 4, tilt: 2))

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -100, y: 0))
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 3, accuracy: 0.000_1, "a new gesture moves it again")
    }

    /// A WRITE OF ONE NUMBER TWO FINGERS HOLD LEAVES THEM THE OTHER: the program sends the size while they spread
    /// and turn - a light table's Closer - and the turn goes on under them; the size is the program's until they lift.
    func testAWriteOfOneNumberTwoFingersHoldLeavesThemTheOther() throws {
        let orbit = State(wrappedValue: Orbit(turn: 1, tilt: 0))
        let moved = orbit.traveling(linear)
        bench.laid {
            MotionLayout([0], parameters: moved) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
            }
            .interaction(.simultaneous([
                .value(moved, axis: \.turn, input: .magnification).range(0.5...4),
                .value(moved, axis: \.tilt, input: .rotation(degreesPerUnit: 90)).range(0...4),
            ]).release(.nearest(self.linear)))
            .node
        }
        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))

        bench.pinch(.began)
        bench.pinch(.changed, scale: 1.5, degrees: 45)
        orbit.wrappedValue.turn = 3
        bench.frames(4)
        bench.pinch(.changed, scale: 1.5, degrees: 45)

        XCTAssertTrue(runtime.interactions.holds(layout), "the fingers hold the turn on")
        let held = try XCTUnwrap(bench.journey)
        XCTAssertEqual(held.value[1], 1, accuracy: 0.000_1, "the tilt under the fingers")
        XCTAssertEqual(held.destination[0], 3, "the size the program's, the fingers spreading it no more")

        bench.pinch(.ended)
        bench.frames(80)
        XCTAssertEqual(orbit.wrappedValue, Orbit(turn: 3, tilt: 1))
    }

    /// A WRITE THAT TOOK A NUMBER FROM ONE HAND TAKES NOTHING FROM TWO FINGERS THAT HELD NONE: the hand's gesture
    /// ended there, and once it lifts the sessions keep nothing of the view - so two fingers that come after move
    /// their own number from their first report, a beginning heard or not.
    func testAWriteTakingAHandsNumberLeavesTwoFingersTheirs() throws {
        let orbit = State(wrappedValue: Orbit())
        let moved = orbit.traveling(linear)
        bench.laid {
            MotionLayout([0], parameters: moved) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
            }
            .interaction(.simultaneous([
                .value(moved, axis: \.turn, input: .translation(.horizontal, unit: .points(100))).range(0...4),
                .value(moved, axis: \.tilt, input: .rotation(degreesPerUnit: 90)).range(0...4),
            ]).release(.nearest(self.linear)))
            .node
        }
        let runtime = try XCTUnwrap(bench.runtime)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: 140, y: 0))
        orbit.wrappedValue.turn = 4
        bench.cycle()
        bench.hand(.ended)
        XCTAssertEqual(runtime.interactions.entries, 0, "the gesture over, nothing of it is kept")

        bench.pinch(.changed, degrees: 90)
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[1], 1, accuracy: 0.000_1, "the fingers' own number moves")
    }

    /// A WRITE OF ANOTHER NUMBER LEAVES THE HAND ITS OWN: the tilt travels where the program sent it while the hand
    /// goes on holding the turn, and letting the turn go leaves the tilt on its way.
    func testAWriteOfAnotherNumberLeavesTheHandItsOwn() throws {
        let orbit = State(wrappedValue: Orbit())
        bench.laid { self.layout(orbit, tilts: false).node }
        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: 140, y: 0))
        orbit.wrappedValue.tilt = 3
        bench.frames(4)
        XCTAssertTrue(runtime.interactions.holds(layout), "the hand holds on")
        bench.hand(.changed, moved: Point(x: 20, y: 0))

        let held = try XCTUnwrap(bench.journey)
        XCTAssertEqual(held.value[0], 1.6, accuracy: 0.000_1, "the turn under the hand")
        XCTAssertGreaterThan(held.value[1], 0, "the tilt on its way")
        XCTAssertLessThan(held.value[1], 3)

        bench.hand(.ended)
        let after = try XCTUnwrap(bench.journey)
        XCTAssertGreaterThan(after.velocity[1], 0, "the tilt keeps its speed")
        bench.frames(80)
        XCTAssertEqual(orbit.wrappedValue, Orbit(turn: 2, tilt: 3))
    }

    /// A view the hand turns across and two fingers tilt: a light table's pan and pinch.
    private func table(_ orbit: State<Orbit>) -> MotionLayout<[Int], Int, Orbit> {
        let moved = orbit.traveling(linear)
        return MotionLayout([0], parameters: moved) { Text("\($0)") } placements: { _, _ in
            [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
        }
        .interaction(.simultaneous([
            .value(moved, axis: \.turn, input: .translation(.horizontal, unit: .points(100))).range(0...4),
            .value(moved, axis: \.tilt, input: .rotation(degreesPerUnit: 90)).range(0...4),
        ]).release(.nearest(linear)))
    }

    /// A WRITE OF WHAT TWO FINGERS MOVE LEAVES ONE FINGER ITS OWN: a finger turning the table while the program
    /// sends the tilt - two fingers' number, not the finger's - turns on, the tilt traveling beside it.
    func testAWriteOfWhatTwoFingersMoveLeavesOneFingerItsOwn() throws {
        let orbit = State(wrappedValue: Orbit())
        bench.laid { self.table(orbit).node }
        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: 140, y: 0))
        orbit.wrappedValue.tilt = 3
        bench.frames(4)
        bench.hand(.changed, moved: Point(x: 20, y: 0))

        XCTAssertTrue(runtime.interactions.holds(layout), "the finger holds on")
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 1.6, accuracy: 0.000_1, "the turn under the finger")
    }

    /// A WRITE TAKES WHAT IT WRITES FROM THE GESTURE HOLDING IT, AND NOTHING FROM ANOTHER: the program sends the tilt
    /// while two fingers tilt and the hand turns - the tilt the program's, and the turn stays under the hand.
    func testAWriteTakesWhatItWritesAndNothingFromAnotherGesture() throws {
        let orbit = State(wrappedValue: Orbit())
        bench.laid { self.table(orbit).node }
        let layout = try XCTUnwrap(bench.layout)
        let runtime = try XCTUnwrap(bench.runtime)

        bench.hand(.began)
        bench.pinch(.began, degrees: 0)
        bench.hand(.changed, moved: Point(x: 140, y: 0))
        bench.pinch(.changed, degrees: 45)
        orbit.wrappedValue.tilt = 3
        bench.frames(4)
        bench.hand(.changed, moved: Point(x: 20, y: 0))
        bench.pinch(.changed, degrees: 90)

        XCTAssertTrue(runtime.interactions.holds(layout), "the hand holds on")
        let held = try XCTUnwrap(bench.journey)
        XCTAssertEqual(held.value[0], 1.6, accuracy: 0.000_1, "the turn under the hand")
        XCTAssertEqual(held.destination[1], 3, "the tilt the program's, the fingers moving it no more")
    }

    /// A HAND THAT WAITS KEEPS THE NUMBER: the state is going where the program sent it at once, the number stays
    /// under the hand, and let go it travels where the program sent it last - not onto a snap of the hand's.
    func testAHandThatWaitsGoesWhereTheProgramSentItLast() throws {
        let orbit = State(wrappedValue: Orbit())
        bench.laid { self.layout(orbit, tilts: false, policy: .deferLatest).node }
        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: 140, y: 0))
        orbit.wrappedValue.turn = 4
        bench.cycle()
        orbit.wrappedValue.turn = 3
        bench.cycle()
        XCTAssertTrue(runtime.interactions.holds(layout), "the hand keeps it")
        XCTAssertEqual(orbit.wrappedValue.turn, 3, "the state is going where the program sent it")

        bench.hand(.changed, moved: Point(x: -100, y: 0))
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 0.4, accuracy: 0.000_1, "under the hand still")
        XCTAssertEqual(orbit.wrappedValue.turn, 3, "the hand names no snap over the program's")

        bench.hand(.ended)
        bench.frames(80)
        XCTAssertEqual(orbit.wrappedValue.turn, 3)
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 3, accuracy: 0.000_1, "where the program sent it last")
    }

    /// A PROGRAM DESCRIBED AGAIN LEAVES WHAT IT STILL MOVES UNDER THE HAND: the number it moves no longer goes onto
    /// where it was bound, once - the other stays held.
    func testAProgramDescribedAgainLeavesWhatItStillMovesUnderTheHand() throws {
        let orbit = State(wrappedValue: Orbit())
        var tilts = true
        bench.laid { self.layout(orbit, tilts: tilts).node }
        let (layout, runtime) = (try XCTUnwrap(bench.layout), try XCTUnwrap(bench.runtime))
        let state = try XCTUnwrap(layout.driven[.parameters]?.state)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: 140, y: 60))
        XCTAssertEqual(runtime.stateChannels.held(state), [0, 1])

        tilts = false
        bench.render()
        XCTAssertEqual(runtime.stateChannels.held(state), [0], "the turn stays under the hand")

        bench.hand(.changed, moved: Point(x: 20, y: 300))
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 1.6, accuracy: 0.000_1, "and goes on with it")
        bench.frames(40)
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[1], 1, accuracy: 0.000_1, "the tilt on the snap it was bound for")
    }

    /// A VIEW THAT LEAVES LETS GO: what its hand held is nobody's, and goes onto where it was bound.
    func testAViewThatLeavesLetsGo() throws {
        let orbit = State(wrappedValue: Orbit())
        var stands = true
        bench.laid {
            ZStack {
                self.layout(orbit, tilts: false)
                if stands { self.layout(orbit, tilts: false).id("leaving") }
            }.node
        }
        let (kept, leaving) = (try XCTUnwrap(bench.layouts.first), try XCTUnwrap(bench.layouts.last))
        let runtime = try XCTUnwrap(bench.runtime)
        let state = try XCTUnwrap(kept.driven[.parameters]?.state)

        bench.hand(.began, on: leaving)
        bench.hand(.changed, moved: Point(x: 140, y: 0), on: leaving)
        XCTAssertEqual(runtime.stateChannels.held(state), [0])

        stands = false
        bench.render()
        XCTAssertTrue(runtime.stateChannels.held(state).isEmpty, "nobody's")
        bench.frames(40)
        XCTAssertEqual(orbit.wrappedValue.turn, 1, "onto the snap it was bound for")

        bench.hand(.began, on: kept)
        bench.hand(.changed, moved: Point(x: 100, y: 0), on: kept)
        XCTAssertEqual(try XCTUnwrap(bench.journey).value[0], 2, accuracy: 0.000_1, "the view that stayed takes it")
    }

    // MARK: - On any view

    /// A panel a hand drags across between three snaps, its place the state itself.
    private func panel(_ offset: State<Double>, release: InteractionRelease = .nearest(.eased(.milliseconds(160), curve: .linear))) -> Node {
        Rectangle()
            .width(100)
            .height(80)
            .translationX(offset.projectedValue)
            .interaction(
                .value(offset.projectedValue, input: .translation(.horizontal))
                    .range(0...240).snaps([120]).release(release))
            .node
    }

    /// A HAND MOVES A STATE ON ANY VIEW: the view hears the hand one way, the state stands under the hand bound for
    /// the snap nearest, and let go it comes onto it - no layout, no engine, no handler of the application's.
    func testAHandMovesAStateOnAnyView() throws {
        let offset = State(wrappedValue: 0.0)
        bench.mounted { self.panel(offset) }
        let panel = try XCTUnwrap(bench.element(.rectangle))
        XCTAssertEqual(panel.hearing, [.hand])
        XCTAssertEqual(panel.handWay, .horizontal)

        bench.hand(.began, on: panel)
        bench.hand(.changed, moved: Point(x: 70, y: 0), on: panel)
        let held = try XCTUnwrap(bench.journey(movedOn: panel))
        XCTAssertEqual(held.value, [70], "under the hand: it grows as the hand moves right")
        XCTAssertEqual(offset.wrappedValue, 120, "bound for the snap nearest")

        bench.hand(.changed, moved: Point(x: 400, y: 0), on: panel)
        XCTAssertLessThan(try XCTUnwrap(bench.journey(movedOn: panel)).value[0], 241, "less and less past its end")

        bench.hand(.ended, on: panel)
        bench.frames(30)
        XCTAssertEqual(offset.wrappedValue, 240, "back onto the end")
        XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: panel)).value, [240])
    }

    /// A WRITE OF THE PROGRAM AND THE HAND SHARE THE VALUE: sent to the middle by a write and caught on its way, the
    /// panel is taken where it is shown, and let go it comes onto a snap from there.
    func testAProgramsJourneyIsCaughtByTheHandOnAnyView() throws {
        let offset = State(wrappedValue: 0.0)
        _ = offset.traveling(.eased(.milliseconds(320), curve: .linear))
        bench.mounted { self.panel(offset) }
        let panel = try XCTUnwrap(bench.element(.rectangle))

        offset.wrappedValue = 240
        bench.frames(9)
        let caught = try XCTUnwrap(bench.journey(movedOn: panel)).value[0]
        XCTAssertGreaterThan(caught, 60, "on its way, past halfway to the middle snap")
        XCTAssertLessThan(caught, 120)

        bench.hand(.began, on: panel)
        XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: panel)).value[0], caught, accuracy: 0.001, "taken where it is shown")
        XCTAssertEqual(offset.wrappedValue, 120, "the program's journey stopped: bound for the snap nearest")
        bench.hand(.ended, on: panel)
        bench.frames(12)
        XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: panel)).value, [120], "on it within the motion's own length")
        XCTAssertEqual(offset.wrappedValue, 120)
    }

    /// A STATE NOTHING DRAWS IS CARRIED FOR THE HAND ALONE: the view that moves it is its channel's consumer, and
    /// `.stay` leaves it where the hand left it.
    func testAStateNothingDrawsIsCarriedForTheHand() throws {
        let moved = State(wrappedValue: 10.0)
        bench.mounted {
            Rectangle()
                .interaction(.value(moved.projectedValue, input: .translation(.horizontal)).release(.stay))
                .node
        }
        let pad = try XCTUnwrap(bench.element(.rectangle))

        bench.hand(.began, on: pad)
        bench.hand(.changed, moved: Point(x: -60, y: 0), on: pad)
        bench.hand(.ended, velocity: Point(x: -900, y: 0), on: pad)
        bench.frames(10)

        XCTAssertEqual(moved.wrappedValue, -50, "as far as the hand went, however fast it let go")
        XCTAssertEqual(try XCTUnwrap(bench.journey(movedOn: pad)).value, [-50])
    }

    /// A UNIT OF THE VIEW'S OWN LENGTH is read off where the view stands: a hand across half of it moves the value
    /// half a unit - and until the view is laid out, nothing.
    func testAUnitOfTheViewsOwnLengthIsReadOffWhereItStands() throws {
        let page = State(wrappedValue: 0.0)
        bench.mounted {
            Rectangle()
                .interaction(
                    .value(page.projectedValue, input: .translation(.horizontal, unit: .containerLength))
                        .reversed(true).range(0...3).release(.stay))
                .node
        }
        let (pages, runtime) = (try XCTUnwrap(bench.element(.rectangle)), try XCTUnwrap(bench.runtime))
        XCTAssertTrue(pages.readsOwnFrame, "it says its frame: the hand's unit is its length")

        bench.hand(.began, on: pages)
        bench.hand(.changed, moved: Point(x: -100, y: 0), on: pages)
        bench.hand(.ended, on: pages)
        XCTAssertEqual(page.wrappedValue, 0, "not laid out yet: nothing to measure, nothing moved")

        pages.reportFrame([0, 0, 400, 300, 0, 0, 0, 0], in: runtime)
        bench.hand(.began, on: pages)
        bench.hand(.changed, moved: Point(x: -200, y: 0), on: pages)
        bench.hand(.ended, on: pages)
        bench.frames(4)
        XCTAssertEqual(page.wrappedValue, 0.5, accuracy: 0.000_1, "half its width, half a unit")
    }
}
