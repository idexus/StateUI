// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout engine: what its arithmetic is handed, where the run puts each child, how the program and the hand move
// the phase, and what it says of an answer it cannot use. The gallery's tests hold the hand at full length.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class LayoutEngineTests: XCTestCase {
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

    // MARK: - The arithmetic

    /// THE ROOM FROM THE LAYOUT'S OWN TOP LEFT: the arithmetic is handed the size the layout was given at the
    /// origin, wherever the layout stands in its parent, and the phase as it stands.
    func testTheArithmeticIsHandedItsRoomFromItsOwnTopLeft() {
        let handed = Handed()

        _ = bench.laid(Renders(), {
            LayoutEngine([1, 2]) { Text("\($0)") } placements: { room, phase in
                handed.rooms.append(room)
                handed.phases.append(phase)
                return [Placement(Rect(0, 0, 10, 10)), Placement(Rect(20, 0, 10, 10))]
            }
            .node
        })

        XCTAssertEqual(handed.rooms.last, Rect(0, 0, 300, 200))
        XCTAssertEqual(handed.phases.last, 0)
    }

    /// THE VIEWS ALONE, IN THE ITEMS' ORDER: a hand lays nothing over them.
    func testTheRunPlacesTheViewsAlone() {
        let (_, run) = bench.laid(Renders(), {
            LayoutEngine([1, 2]) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(0, 0, 10, 10), zIndex: 5), Placement(Rect(20, 0, 10, 10))]
            }
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 1])
            .node
        })

        XCTAssertEqual(run.map(\.bounds), [Rect(0, 0, 10, 10), Rect(20, 0, 10, 10)])
    }

    /// THE HAND IS HEARD ON THE ELEMENT ITSELF, over every view, which way it moves the run said to the host.
    func testTheHandIsHeardOnTheElementItself() throws {
        let patch = Renders().render(
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .input(.scroll(.vertical, pointsPerUnit: 100))
                .snapTargets([0, 1])
                .node)
        let layout = try XCTUnwrap(patch.first(.layoutEngine))

        XCTAssertNotNil(layout.events?[.handMoved])
        XCTAssertEqual(layout.props[.handAxis], LayoutInput.Axis.vertical.propValue)
        XCTAssertNil(patch.first(.scrollView), "nothing scrolls under the hand")
    }

    /// AN ANSWER OF THE WRONG LENGTH IS SAID AND MADE TO FIT: one placement a view, the rest at the top left.
    func testAnAnswerOfTheWrongLengthIsSaidAndMadeToFit() {
        let (_, run) = bench.laid(Renders(), {
            LayoutEngine([1, 2, 3]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(5, 5, 10, 10))] }.node
        })

        XCTAssertEqual(run.prefix(3).map(\.bounds), [Rect(5, 5, 10, 10), .zero, .zero])
        XCTAssertTrue(hasComplained("placements answered 1 placements for 3 views"))
    }

    // MARK: - The phase

    /// THE LAYOUT'S ELEMENT WEARS ITS PHASE, both ways, so the host walks it under the layout's motion and says where
    /// it stands every frame: what makes a move of the phase travel, and an awaited one arrive.
    func testTheLayoutsElementWearsItsPhase() async throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .phase(phase.projectedValue)
                .node
        }

        let (patch, _) = bench.laid(renders, tree)
        let worn = try XCTUnwrap(patch.first(.layoutEngine)?.driven?[.phase])

        XCTAssertEqual(worn.mode, .inOut)
        XCTAssertEqual(worn.kind, .property)

        phase.wrappedValue = 2
        bench.cycle()
        XCTAssertEqual(try XCTUnwrap(standing(worn.state, as: JourneyLanes<Double>.self)).destination, 2,
                       "the phase written is where the host walks it")
    }

    /// A PHASE IS A STATE: a binding worked out from others cannot be worn, so it is said once - its phase would jump.
    func testAPhaseWorkedOutFromOthersIsSaid() {
        var stored = 0.0
        _ = Renders().render(
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [] }
                .phase(Binding(get: { stored }, set: { stored = $0 }))
                .node)

        XCTAssertTrue(hasComplained("A LayoutEngine's phase is a state lent with `$`"))
    }

    /// WITHOUT A HAND THE PHASE TRAVELS AS THE HOST WALKS IT: a write is where the run goes, and the arithmetic is
    /// handed each frame where the host says the phase stands - never the destination at once.
    func testWithoutAHandThePhaseTravelsAsTheHostWalksIt() async throws {
        let handed = Handed()
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, phase in
                handed.phases.append(phase)
                return [Placement(Rect(phase * 10, 0, 10, 10))]
            }
            .phase(phase.projectedValue)
            .node
        }

        let (patch, _) = bench.laid(renders, tree)
        let worn = try XCTUnwrap(patch.first(.layoutEngine)?.driven?[.phase]?.state)

        phase.wrappedValue = 2
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        _ = await settle()
        bench.cycle()
        XCTAssertEqual(handed.phases.last, 0, "the write is where it goes; the host has walked nothing yet")

        moved(worn, to: 1)
        bench.cycle()
        XCTAssertEqual(handed.phases.last, 1, "a frame on the way")

        moved(worn, to: [2, 2, 0], mask: 0b111)
        bench.cycle()
        XCTAssertEqual(handed.phases.last, 2, "and where it landed")
    }

    /// THE HAND MOVES THE RUN WITH IT, and names the nearest target, uneven ones too, as it passes halfway between
    /// two: a reading of the hand, not a journey.
    func testTheHandNamesTheNearestOfUnevenTargets() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, targets: [0, 0.2, 0.5, 1]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-40, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.4, accuracy: 0.001, "where the hand holds it: left moves it on")
        XCTAssertEqual(phase.wrappedValue, 0.5, "0.4 is nearer 0.5 than 0.2")
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self)).value, 0.5, "named, not sent")

        bench.hand(renders, tree, .changed, moved: Point(35, 0))
        XCTAssertEqual(phase.wrappedValue, 0, "0.05 is nearest 0")
    }

    /// THE HAND TAKES THE RUN WHERE IT STANDS: from the phase it was started at, a journey under way stopping
    /// where it is shown.
    func testTheHandTakesTheRunWhereItIsShown() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, targets: [0, 0.5, 1]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        phase.wrappedValue = 1
        bench.cycle()
        moved(worn, to: 0.3)
        bench.cycle()
        bench.hand(renders, tree, .began)

        XCTAssertEqual(handed.phases.last ?? 0, 0.3, accuracy: 0.001, "held where it was shown")
        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(journey.destination, 0.5, "the program's journey stopped, the nearest target named")
        XCTAssertEqual(phase.wrappedValue, 0.5)
    }

    /// LET GO STILL, THE RUN TRAVELS ON from where the hand left it to the nearest target, as a journey of its own.
    func testLetGoStillTheRunTravelsToTheNearestTarget() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { handTree(phase, targets: [0, 0.5, 1]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-40, 0))
        bench.hand(renders, tree, .ended)

        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(journey.value, 0.4, accuracy: 0.001, "from where the hand left it")
        XCTAssertEqual(journey.destination, 0.5, "to the nearest target")
    }

    /// A THROW GOES ON TO THE TARGET NEAREST WHERE IT WOULD END, by the hand's own deceleration: named at once,
    /// it sets out at the hand's speed, never faster, and stops on the target - never past the last target of a run
    /// that does not come round.
    func testAThrowGoesOnToTheTargetNearestWhereItWouldEnd() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, targets: [0, 1, 2, 3, 4, 5, 6]) }

        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-10, 0))
        // 450 points a second to the left is 4.5 units a second, which the throw carries 0.6 units on.
        bench.hand(renders, tree, .ended, speed: Point(-450, 0))
        XCTAssertEqual(phase.wrappedValue, 1, "0.1 and 0.6 on is nearest 1, named at once")

        let start = handed.phases.count
        bench.cycle()
        let first = (handed.phases.last ?? 0) - (handed.phases.dropLast().last ?? 0)
        XCTAssertEqual(first / 0.016, 4.5, accuracy: 0.15, "setting out at the hand's speed")

        for _ in 0..<400 { bench.cycle() }
        XCTAssertEqual(handed.phases.last ?? 0, 1, accuracy: 0.000_1, "and at rest on the target")
        let flight = Array(handed.phases[(start - 1)...])
        XCTAssertTrue(zip(flight.dropLast(), flight.dropFirst()).allSatisfy { $1 - $0 <= first + 0.000_001 },
                      "never faster than the hand let go")

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .ended, speed: Point(-100_000, 0))
        XCTAssertEqual(phase.wrappedValue, 6, "the last target, however hard the throw")
    }

    /// HOW A THROW GOES ON IS THE INPUT'S, a motion as any other: eased, it carries the hand's speed for its
    /// length over how steeply its curve sets out; a spring, for a third of its response.
    func testHowAThrowGoesOnIsTheInputs() throws {
        for throwing in [Motion.eased(.seconds(3), .cubicOut), .spring(response: .seconds(3))] {
            Renderer.shared.clearStates()
            let phase = State(wrappedValue: 0.0)
            let renders = Renders()
            func tree() -> Node {
                LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                    .phase(phase.projectedValue)
                    .input(.scroll(.horizontal, pointsPerUnit: 100, throwing: throwing))
                    .snapTargets([0, 1, 2, 3, 4, 5, 6])
                    .node
            }

            _ = bench.laid(renders, tree)
            bench.hand(renders, tree, .began)
            bench.hand(renders, tree, .changed, moved: Point(-10, 0))
            bench.hand(renders, tree, .ended, speed: Point(-300, 0))

            XCTAssertEqual(phase.wrappedValue, 3, "3 units a second for a second: 0.1 and 3 on, \(throwing.law)")
        }
    }

    /// A THROW TOO SLOW TO CARRY THE RUN PAST THE TARGET IT STANDS NEAREST SLIDES THERE under the layout's motion,
    /// as a run let go still does - never thrown back against the hand.
    func testAThrowTooSlowToPassItsNearestSlidesThere() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { handTree(phase, targets: [0, 1, 2]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-105, 0))
        // 120 points a second carries the run 0.16 on: from 1.05 to 1.21, still nearest 1, behind the hand.
        bench.hand(renders, tree, .ended, speed: Point(-120, 0))

        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(journey.value, 1.05, accuracy: 0.001, "from where the hand left it")
        XCTAssertEqual(journey.destination, 1, "to the nearest, as a journey under the layout's motion")
    }

    /// PAST AN END THE HAND MOVES THE RUN HALF AS FAR, and let go, the run comes back to the end.
    func testPastAnEndTheHandMovesTheRunHalfAsFar() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, targets: [0, 1]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(100, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.5, accuracy: 0.001)

        bench.hand(renders, tree, .ended)
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self)).destination, 0)
    }

    /// A RUN THAT COMES ROUND HAS NO END: past the last target is the first again, a turn on, and a throw there
    /// rests a turn on rather than going back.
    func testARunThatComesRoundHasNoEnd() throws {
        let phase = State(wrappedValue: 6.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, at in
                handed.phases.append(at)
                return [Placement(Rect(0, 0, 10, 10))]
            }
            .phase(phase.projectedValue)
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 1, 2, 3, 4, 5, 6])
            .wraps(every: 7)
            .node
        }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.layoutEngine)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-120, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 7.2, accuracy: 0.001, "on past the last card, at full speed")
        XCTAssertEqual(phase.wrappedValue, 7, "the first card, a turn on")

        bench.hand(renders, tree, .ended)
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self)).destination, 7)
    }

    /// A layout of one view a hand moves, a hundred points a unit, over `targets`.
    private func handTree(_ phase: State<Double>, handed: Handed? = nil, targets: [Double]) -> Node {
        LayoutEngine([1]) { Text("\($0)") } placements: { _, at in
            handed?.phases.append(at)
            return [Placement(Rect(0, 0, 10, 10))]
        }
        .phase(phase.projectedValue)
        .input(.scroll(.horizontal, pointsPerUnit: 100))
        .snapTargets(targets)
        .node
    }

    /// A HAND NEEDS ITS TARGETS: they say how far it moves the run and where it rests, so one given none hears no
    /// hand and says why.
    func testAHandWithNoSnapTargetsMovesNothing() throws {
        let patch = Renders().render(
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [] }
                .input(.scroll(.vertical, pointsPerUnit: 50))
                .node)

        XCTAssertNil(try XCTUnwrap(patch.first(.layoutEngine)).events?[.handMoved])
        XCTAssertTrue(hasComplained("given a scroll but no snap targets on the axis it drives"))
    }

    // MARK: - A tap

    /// A TAP LANDS ON THE VIEW ITSELF, with its item, a hand over the layout or none: nothing lies over the views.
    func testATapLandsOnTheViewItself() async throws {
        var heard: [Int] = []
        let renders = Renders()
        let patch = renders.render(
            LayoutEngine([7, 8]) { Text("\($0)") } placements: { _, _ in [] }
                .input(.scroll(.horizontal, pointsPerUnit: 100))
                .snapTargets([0, 1])
                .onItemTapped { heard.append($0) }
                .node)
        let layout = try XCTUnwrap(patch.first(.layoutEngine))
        let tap = try XCTUnwrap(layout.children[1].events?[.tapped])

        XCTAssertTrue(renders.fire(tap))
        _ = await settle()

        XCTAssertEqual(heard, [8])
    }
}

