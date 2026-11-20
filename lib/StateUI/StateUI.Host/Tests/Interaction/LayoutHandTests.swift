// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A motion layout under the hand: the run moves with it and is bound for the snap nearest, lets go onto it or is
// thrown on, gives less and less past an end, comes round, and steps a wheel's notch.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

@MainActor
final class LayoutHandTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
    private final class Handed {
        var rooms: [Rect] = []
        var phases: [Double] = []
    }

    /// The bench the layouts are rendered, told their room and turned on.
    private let bench = LayoutBench()

    // MARK: - The phase

    /// THE HAND MOVES THE RUN WITH IT, and names the nearest target, uneven ones too, as it passes halfway between
    /// two: where the run is going, while it stands under the hand.
    func testTheHandNamesTheNearestOfUnevenTargets() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1, snaps: [0.2, 0.5]) }

        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-40, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.4, accuracy: 0.001, "where the hand holds it: left moves it on")
        XCTAssertEqual(phase.wrappedValue, 0.5, "0.4 is nearer 0.5 than 0.2")
        let held = try XCTUnwrap(bench.journey)
        XCTAssertEqual(held.value[0], 0.4, accuracy: 0.000_1, "under the hand")
        XCTAssertEqual(held.destination[0], 0.5, "bound for the snap named, not sent there")
        XCTAssertEqual(held.velocity[0], 0)

        bench.hand(.changed, moved: Point(35, 0))
        XCTAssertEqual(phase.wrappedValue, 0, "0.05 is nearest 0")
    }

    /// WITH NO UNIT GIVEN, THE HAND CARRIES THE VIEW IN FRONT: the hand travels as far for a unit of the phase as
    /// the view drawn on top of those the phase moves goes for it, so that view stays under the finger whatever the
    /// room makes of it - a view standing still over them, a dot, a caption, carries nothing.
    func testWithNoUnitTheHandCarriesTheViewInFront() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node {
            MotionLayout([0, 1, 2], parameters: phase.projectedValue) { Text("\($0)") } placements: { context, at in
                handed.phases.append(at)
                // The view in front moves half the room's width a unit; the one behind it, a tenth as far.
                return [
                    Placement(Rect(-at * context.bounds.width / 10, 0, 10, 10)),
                    Placement(Rect(-at * context.bounds.width / 2, 0, 10, 10), zIndex: 1),
                    Placement(Rect(0, 0, 10, 10), zIndex: 2),
                ]
            }
            .interaction(
                Interaction.value(phase.projectedValue, axis: \.self, input: .translation(.horizontal, unit: .frontItem)).reversed(true).range(0...2).snaps(.every(1))
                    .release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
            .node
        }
        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-150, 0))

        XCTAssertEqual(handed.phases.last ?? 0, 1, accuracy: 0.001, "half the room's 300 is a unit")
    }

    /// A ROOM NOT YET MEASURED DRAWS NO VIEW, SO A HAND OVER IT MOVES NONE: with no unit given there is nothing in
    /// front to carry, and the run stays where it stands - neither moved nor thrown.
    func testAHandOverARoomNotYetMeasuredMovesNothing() throws {
        let phase = State(wrappedValue: 0.0)
        func tree() -> Node {
            MotionLayout([0, 1, 2], parameters: phase.projectedValue) { Text("\($0)") } placements: { context, at in
                (0..<3).map { Placement(Rect((Double($0) - at) * context.bounds.width / 2, 0, 10, 10)) }
            }
            .interaction(
                Interaction.value(phase.projectedValue, axis: \.self, input: .translation(.horizontal, unit: .frontItem)).reversed(true).range(0...2).snaps(.every(1))
                    .release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
            .node
        }
        bench.laid(tree, room: nil)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-80, 0))
        bench.hand(.ended, velocity: Point(-2_000, 0))

        XCTAssertEqual(phase.wrappedValue, 0, "no card named, none thrown to")
    }

    /// THE HAND TAKES THE RUN WHERE IT STANDS: from the phase it was started at, a journey under way stopping
    /// where it is shown.
    func testTheHandTakesTheRunWhereItIsShown() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1, snaps: [0.5]) }

        _ = phase.traveling(.eased(.milliseconds(320), curve: .linear))
        bench.laid(tree)

        phase.wrappedValue = 1
        bench.frames(9)
        let shown = try XCTUnwrap(handed.phases.last)
        XCTAssertGreaterThan(shown, 0.25, "on its way, nearest the middle snap")
        XCTAssertLessThan(shown, 0.75)
        bench.hand(.began)

        XCTAssertEqual(handed.phases.last ?? 0, shown, accuracy: 0.001, "held where it was shown")
        let journey = try XCTUnwrap(bench.journey)
        XCTAssertEqual(journey.destination[0], 0.5, "the program's journey stopped, the nearest target named")
        XCTAssertEqual(phase.wrappedValue, 0.5)
    }

    /// LET GO STILL, THE RUN COMES ONTO THE NEAREST TARGET, named at once, from where the hand left it.
    func testLetGoStillTheRunComesOntoTheNearestTarget() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1, snaps: [0.5]) }

        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-40, 0))
        bench.hand(.ended)
        XCTAssertEqual(phase.wrappedValue, 0.5, "the nearest target")

        bench.cycle()
        XCTAssertGreaterThan(handed.phases.last ?? 0, 0.4, "on its way from where the hand left it")
        for _ in 0..<20 { bench.cycle() }
        XCTAssertEqual(handed.phases.last ?? 0, 0.5, accuracy: 0.000_1)
    }

    /// A THROW GOES ON TO THE TARGET NEAREST WHERE IT WOULD END, by the hand's own deceleration: named at once,
    /// past the next target it sets out at the hand's speed, never faster, and stops on the target - never past the
    /// last target of a run that does not come round.
    func testAThrowGoesOnToTheTargetNearestWhereItWouldEnd() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...6) }

        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-10, 0))
        // 1500 points a second to the left is 15 units a second, which the throw carries 2 units on.
        bench.hand(.ended, velocity: Point(-1_500, 0))
        XCTAssertEqual(phase.wrappedValue, 2, "0.1 and 2 on is nearest 2, named at once")

        let start = handed.phases.count
        bench.cycle()
        let first = (handed.phases.last ?? 0) - (handed.phases.dropLast().last ?? 0)
        XCTAssertEqual(first / 0.016, 15, accuracy: 1, "setting out at the hand's speed")

        for _ in 0..<400 { bench.cycle() }
        XCTAssertEqual(handed.phases.last ?? 0, 2, accuracy: 0.000_1, "and at rest on the target")
        let flight = Array(handed.phases[(start - 1)...])
        XCTAssertTrue(zip(flight.dropLast(), flight.dropFirst()).allSatisfy { $1 - $0 <= first + 0.000_001 },
                      "never faster than the hand let go")

        bench.hand(.began)
        bench.hand(.ended, velocity: Point(-100_000, 0))
        XCTAssertEqual(phase.wrappedValue, 6, "the last target, however hard the throw")
    }

    /// HOW A THROW GOES ON IS THE INPUT'S, a motion as any other: eased, it carries the hand's speed for its
    /// length over how steeply its curve sets out; a spring, for a third of its response.
    func testHowAThrowGoesOnIsTheInputs() throws {
        for throwing in [Motion.eased(.seconds(3), curve: .cubicOut), .spring(Spring(response: .seconds(3)))] {
            Renderer.shared.clearStates()
            let phase = State(wrappedValue: 0.0)
            func tree() -> Node {
                MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                    .interaction(
                        Interaction.value(phase.projectedValue, axis: \.self, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...6).snaps(.every(1))
                            .release(.projected(throwing)))
                    .node
            }

            bench.laid(tree)
            bench.hand(.began)
            bench.hand(.changed, moved: Point(-10, 0))
            bench.hand(.ended, velocity: Point(-300, 0))

            XCTAssertEqual(phase.wrappedValue, 3, "3 units a second for a second: 0.1 and 3 on, \(throwing.kind)")
        }
    }

    /// A THROW TOO SLOW TO CARRY THE RUN PAST THE TARGET IT STANDS NEAREST COMES BACK ONTO IT, as a run let go
    /// still does - never thrown on past where the hand left it.
    func testAThrowTooSlowToPassItsNearestComesBackOntoIt() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...2) }

        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-105, 0))
        // 120 points a second carries the run 0.16 on: from 1.05 to 1.21, still nearest 1, behind the hand.
        bench.hand(.ended, velocity: Point(-120, 0))
        XCTAssertEqual(phase.wrappedValue, 1, "the nearest")

        let start = handed.phases.count
        for _ in 0..<20 { bench.cycle() }
        XCTAssertTrue(handed.phases[start...].allSatisfy { $0 <= 1.05 + 0.000_001 }, "never on past the hand")
        XCTAssertEqual(handed.phases.last ?? 0, 1, accuracy: 0.000_1)
    }

    /// PAST AN END THE RUN GIVES LESS AND LESS, half as far at first and never three quarters of a unit past the end,
    /// however far the hand goes - and let go, the run comes back to the end.
    func testPastAnEndTheRunGivesLessAndLess() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1) }

        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(10, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.05, accuracy: 0.005, "half as far at first")
        bench.hand(.changed, moved: Point(90, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.3, accuracy: 0.001, "a unit of the hand, less than half")
        bench.hand(.changed, moved: Point(1_000, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.66, accuracy: 0.001, "eleven, short of three quarters")

        bench.hand(.changed, moved: Point(-1_100, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0, accuracy: 0.001, "back the way it came, back at the end")

        // From the first target across the last: a whole unit to the end, then less and less of what is left.
        bench.hand(.changed, moved: Point(-160, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1.2143, accuracy: 0.001, "only the way past the end gives")

        bench.hand(.ended)
        XCTAssertEqual(try XCTUnwrap(bench.journey).destination[0], 1)
    }

    /// A RUN THAT COMES ROUND HAS NO END: past the last target is the first again, a turn on, and a throw there
    /// rests a turn on rather than going back.
    func testARunThatComesRoundHasNoEnd() throws {
        let phase = State(wrappedValue: 6.0)
        let handed = Handed()
        func tree() -> Node {
            MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                handed.phases.append(at)
                return [Placement(Rect(0, 0, 10, 10))]
            }
            .interaction(
                Interaction.value(phase.projectedValue, axis: \.self, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...7).snaps(.every(1)).periodic(true)
                    .release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
            .node
        }

        bench.laid(tree)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(-120, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 7.2, accuracy: 0.001, "on past the last card, at full speed")
        XCTAssertEqual(phase.wrappedValue, 7, "the first card, a turn on")

        bench.hand(.ended)
        XCTAssertEqual(try XCTUnwrap(bench.journey).destination[0], 7)
    }

    /// A layout of one view a hand moves, a hundred points a unit, over `range`, resting on `snaps`.
    private func handTree(
        _ phase: State<Double>, handed: Handed? = nil, range: ClosedRange<Double>, snaps: AxisValues? = .every(1)
    ) -> Node {
        MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            handed?.phases.append(at)
            return [Placement(Rect(0, 0, 10, 10))]
        }
        .interaction(
            Interaction.value(phase.projectedValue, axis: \.self, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(range).snaps(snaps)
                .release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
        .node
    }

    /// A WHEEL'S NOTCH STEPS THE RUN TO THE NEXT TARGET that way, under the layout's motion - however far apart the
    /// targets stand - and the next notch steps on from where the run is going, not from where it is shown yet.
    func testANotchStepsTheRunToTheNextTarget() throws {
        let phase = State(wrappedValue: 0.0)
        func tree() -> Node { handTree(phase, range: 0...1, snaps: [0.2, 0.5]) }

        bench.laid(tree)

        bench.step(Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 0.2, "a notch moving what is under the hand to the left steps it on")
        let sent = try XCTUnwrap(bench.journey)
        XCTAssertEqual(sent.destination[0], 0.2, accuracy: 0.001, "a journey of the phase")
        XCTAssertEqual(sent.value[0], 0, accuracy: 0.001, "from where it stood")

        bench.step(Point(-2, 0))
        XCTAssertEqual(phase.wrappedValue, 1, "two on from where it is going")

        bench.step(Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 1, "held to the last")

        bench.step(Point(1, 0))
        XCTAssertEqual(phase.wrappedValue, 0.5, "and back")
    }

    /// A RUN THAT COMES ROUND IS STEPPED ROUND: a notch past the last target is the first again, a turn on.
    func testANotchStepsARunThatComesRoundATurnOn() throws {
        let phase = State(wrappedValue: 3.0)
        func tree() -> Node {
            MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .interaction(
                    Interaction.value(phase.projectedValue, axis: \.self, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...4).snaps(.every(1)).periodic(true)
                        .release(.projected(.eased(.milliseconds(400), curve: .cubicOut))))
                .node
        }
        bench.laid(tree)

        bench.step(Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 4, "a turn on, the first again")

        bench.step(Point(2, 0))
        XCTAssertEqual(phase.wrappedValue, 2, "back across the turn")
    }

    /// A HAND HOLDING THE RUN KEEPS IT: a notch meanwhile moves nothing.
    func testANotchLeavesARunTheHandHolds() throws {
        let phase = State(wrappedValue: 0.0)
        func tree() -> Node { handTree(phase, range: 0...2) }
        bench.laid(tree)

        bench.hand(.began)
        bench.step(Point(-1, 0))

        XCTAssertEqual(phase.wrappedValue, 0)
    }

    /// A NOTCH MOVES AN AXIS WITH NO SNAPS as far as a hand going a notch's travel would, and no farther than the
    /// range's end.
    func testANotchMovesAnAxisWithNoSnapsANotchsTravel() throws {
        let phase = State(wrappedValue: 0.0)
        func tree() -> Node { handTree(phase, range: 0...1.5, snaps: nil) }
        bench.laid(tree)

        bench.step(Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 1, accuracy: 0.001, "a hundred points, a unit")

        bench.step(Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 1.5, accuracy: 0.001, "held to the end")
    }

}

