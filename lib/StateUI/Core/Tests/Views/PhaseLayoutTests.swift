// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A phase layout: what its arithmetic is handed, where the run puts each child, how the program and the hand move
// the phase, and what it says of an answer it cannot use. The gallery's tests hold the hand at full length.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class PhaseLayoutTests: XCTestCase {
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

    // MARK: - The walk

    /// THE LAYOUT NAMES EVERY PART A MIRROR WOULD, in the same order under the same labels: a field added and not
    /// named would be an input never compared, or a state never kept.
    func testTheLayoutNamesEveryPartAMirrorWould() {
        let layout = PhaseLayout([1, 2], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }
            .axis(\.self, input: .scroll(.horizontal), range: 0...1)

        XCTAssertEqual(layout.walkedParts.map(\.label), Mirror(reflecting: layout).children.map { $0.label ?? "" })
    }

    /// A SLOT IS ITS ITEM'S OWN IDENTITY, compared as the value it is and numbered by the layout: two identities
    /// that describe alike - a class prints its type's name - are two slots, an identity keeps its number while it
    /// stands, a new one takes a number never given, and naming one spells nothing.
    func testASlotIsItsItemsOwnIdentity() {
        let tags = [Tag(1), Tag(2)]
        let layout = PhaseLayout(tags, id: \.self, phase: State(wrappedValue: 0.0).projectedValue) { _ in
            Rectangle()
                .fill(.red)
        } placements: { _, _ in [] }
        let texts = Renderer.shared.texts

        let slots = layout.run.slots

        XCTAssertEqual(Set(slots.map(\.identity)).count, 2, "two identities, two slots")
        XCTAssertEqual(Renderer.shared.texts, texts, "no text built")

        let numbers = LayoutSlotNumbers()
        let first = numbers.numbered([AnyHashable(Tag(1)), AnyHashable(Tag(2))])
        XCTAssertEqual(numbers.numbered([AnyHashable(Tag(2)), AnyHashable(Tag(1))]), first.reversed(), "kept, reordered")
        XCTAssertEqual(numbers.numbered([AnyHashable(Tag(3))]).first.map { first.contains($0) }, false, "never again")
        XCTAssertNotEqual(numbers.numbered([AnyHashable(Tag(1))]), [first[0]], "let go once gone")
    }

    /// An identity whose description says only its type.
    private final class Tag: Hashable {
        let number: Int

        init(_ number: Int) { self.number = number }

        static func == (lhs: Tag, rhs: Tag) -> Bool { lhs.number == rhs.number }
        func hash(into hasher: inout Hasher) { hasher.combine(number) }
    }

    // MARK: - The arithmetic

    /// THE ROOM FROM THE LAYOUT'S OWN TOP LEFT: the arithmetic is handed the size the layout was given at the
    /// origin, wherever the layout stands in its parent, and the phase as it stands.
    func testTheArithmeticIsHandedItsRoomFromItsOwnTopLeft() {
        let handed = Handed()

        _ = bench.laid(Renders(), {
            PhaseLayout([1, 2], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { room, phase in
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
            PhaseLayout([1, 2], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(0, 0, 10, 10), zIndex: 5), Placement(Rect(20, 0, 10, 10))]
            }
            .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...1, snaps: .every(1))
            .node
        })

        XCTAssertEqual(run.map(\.bounds), [Rect(0, 0, 10, 10), Rect(20, 0, 10, 10)])
    }

    /// THE HAND IS HEARD ON THE ELEMENT ITSELF, over every view, which way it moves the run said to the host.
    func testTheHandIsHeardOnTheElementItself() throws {
        let patch = Renders().render(
            PhaseLayout([1], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .axis(\.self, input: .scroll(.vertical, pointsPerUnit: 100), range: 0...1, snaps: .every(1))
                .node)
        let layout = try XCTUnwrap(patch.first(.phaseLayout))

        XCTAssertNotNil(layout.events?[.handMoved])
        XCTAssertEqual(layout.props[.handAxis], LayoutInput.Axis.vertical.propValue)
        XCTAssertNil(patch.first(.scrollView), "nothing scrolls under the hand")
    }

    /// A LAYOUT PLACES AS WRITTEN UNLESS IT MIRRORS RIGHT TO LEFT: the element says so only where the author asks.
    func testALayoutPlacesAsWrittenUnlessItMirrorsRightToLeft() throws {
        func layout(_ mirrors: Bool?) throws -> HostPatch {
            var layout = PhaseLayout([1], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(0, 0, 10, 10))]
            }
            if let mirrors { layout = layout.mirrorsRightToLeft(mirrors) }
            return try XCTUnwrap(Renders().render(layout.node).first(.phaseLayout))
        }

        XCTAssertNil(try layout(nil).props[.mirrorsRightToLeft], "as written")
        XCTAssertNil(try layout(false).props[.mirrorsRightToLeft], "as written")
        XCTAssertEqual(try layout(true).props[.mirrorsRightToLeft], .bool(true))
    }

    /// AN ANSWER OF THE WRONG LENGTH IS SAID AND MADE TO FIT: one placement a view, the rest at the top left.
    func testAnAnswerOfTheWrongLengthIsSaidAndMadeToFit() {
        let (_, run) = bench.laid(Renders(), {
            PhaseLayout([1, 2, 3], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(5, 5, 10, 10))] }.node
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
            PhaseLayout([1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .node
        }

        let (patch, _) = bench.laid(renders, tree)
        let worn = try XCTUnwrap(patch.first(.phaseLayout)?.driven?[.phase])

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
            PhaseLayout([1], phase: Binding(get: { stored }, set: { stored = $0 })) { Text("\($0)") } placements: { _, _ in [] }
                .node)

        XCTAssertTrue(hasComplained("A PhaseLayout's phase is a state lent with `$`"))
    }

    /// WITHOUT A HAND THE PHASE TRAVELS AS THE HOST WALKS IT: a write is where the run goes, and the arithmetic is
    /// handed each frame where the host says the phase stands - never the destination at once.
    func testWithoutAHandThePhaseTravelsAsTheHostWalksIt() async throws {
        let handed = Handed()
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            PhaseLayout([1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, phase in
                handed.phases.append(phase)
                return [Placement(Rect(phase * 10, 0, 10, 10))]
            }
            .node
        }

        let (patch, _) = bench.laid(renders, tree)
        let worn = try XCTUnwrap(patch.first(.phaseLayout)?.driven?[.phase]?.state)

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
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1, snaps: [0.2, 0.5]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.phaseLayout)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-40, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0.4, accuracy: 0.001, "where the hand holds it: left moves it on")
        XCTAssertEqual(phase.wrappedValue, 0.5, "0.4 is nearer 0.5 than 0.2")
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self)).value, 0.5, "named, not sent")

        bench.hand(renders, tree, .changed, moved: Point(35, 0))
        XCTAssertEqual(phase.wrappedValue, 0, "0.05 is nearest 0")
    }

    /// WITH NO UNIT GIVEN, THE HAND CARRIES THE VIEW IN FRONT: the hand travels as far for a unit of the phase as
    /// the view drawn on top of those the phase moves goes for it, so that view stays under the finger whatever the
    /// room makes of it - a view standing still over them, a dot, a caption, carries nothing.
    func testWithNoUnitTheHandCarriesTheViewInFront() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node {
            PhaseLayout([0, 1, 2], phase: phase.projectedValue) { Text("\($0)") } placements: { room, at in
                handed.phases.append(at)
                // The view in front moves half the room's width a unit; the one behind it, a tenth as far.
                return [
                    Placement(Rect(-at * room.width / 10, 0, 10, 10)),
                    Placement(Rect(-at * room.width / 2, 0, 10, 10), zIndex: 1),
                    Placement(Rect(0, 0, 10, 10), zIndex: 2),
                ]
            }
            .axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))
            .node
        }
        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-150, 0))

        XCTAssertEqual(handed.phases.last ?? 0, 1, accuracy: 0.001, "half the room's 300 is a unit")
    }

    /// A ROOM NOT YET MEASURED DRAWS NO VIEW, SO A HAND OVER IT MOVES NONE: with no unit given there is nothing in
    /// front to carry, and the run stays where it stands - neither moved nor thrown.
    func testAHandOverARoomNotYetMeasuredMovesNothing() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            PhaseLayout([0, 1, 2], phase: phase.projectedValue) { Text("\($0)") } placements: { room, at in
                (0..<3).map { Placement(Rect((Double($0) - at) * room.width / 2, 0, 10, 10)) }
            }
            .axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))
            .node
        }
        _ = renders.render(tree())
        bench.cycle()

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-80, 0))
        bench.hand(renders, tree, .ended, speed: Point(-2_000, 0))

        XCTAssertEqual(phase.wrappedValue, 0, "no card named, none thrown to")
    }

    /// THE HAND TAKES THE RUN WHERE IT STANDS: from the phase it was started at, a journey under way stopping
    /// where it is shown.
    func testTheHandTakesTheRunWhereItIsShown() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1, snaps: [0.5]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.phaseLayout)?.driven?[.phase]?.state)

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

    /// LET GO STILL, THE RUN COMES ONTO THE NEAREST TARGET, named at once, from where the hand left it.
    func testLetGoStillTheRunComesOntoTheNearestTarget() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1, snaps: [0.5]) }

        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-40, 0))
        bench.hand(renders, tree, .ended)
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
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...6) }

        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-10, 0))
        // 1500 points a second to the left is 15 units a second, which the throw carries 2 units on.
        bench.hand(renders, tree, .ended, speed: Point(-1_500, 0))
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
                PhaseLayout([1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                    .axis(
                        \.self, input: .scroll(.horizontal, pointsPerUnit: 100, throwing: throwing), range: 0...6,
                        snaps: .every(1))
                    .node
            }

            _ = bench.laid(renders, tree)
            bench.hand(renders, tree, .began)
            bench.hand(renders, tree, .changed, moved: Point(-10, 0))
            bench.hand(renders, tree, .ended, speed: Point(-300, 0))

            XCTAssertEqual(phase.wrappedValue, 3, "3 units a second for a second: 0.1 and 3 on, \(throwing.kind)")
        }
    }

    /// A THROW TOO SLOW TO CARRY THE RUN PAST THE TARGET IT STANDS NEAREST COMES BACK ONTO IT, as a run let go
    /// still does - never thrown on past where the hand left it.
    func testAThrowTooSlowToPassItsNearestComesBackOntoIt() throws {
        let phase = State(wrappedValue: 0.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...2) }

        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-105, 0))
        // 120 points a second carries the run 0.16 on: from 1.05 to 1.21, still nearest 1, behind the hand.
        bench.hand(renders, tree, .ended, speed: Point(-120, 0))
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
        let renders = Renders()
        func tree() -> Node { handTree(phase, handed: handed, range: 0...1) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.phaseLayout)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(10, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.05, accuracy: 0.005, "half as far at first")
        bench.hand(renders, tree, .changed, moved: Point(90, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.3, accuracy: 0.001, "a unit of the hand, less than half")
        bench.hand(renders, tree, .changed, moved: Point(1_000, 0))
        XCTAssertEqual(handed.phases.last ?? 0, -0.66, accuracy: 0.001, "eleven, short of three quarters")

        bench.hand(renders, tree, .changed, moved: Point(-1_100, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 0, accuracy: 0.001, "back the way it came, back at the end")

        // From the first target across the last: a whole unit to the end, then less and less of what is left.
        bench.hand(renders, tree, .changed, moved: Point(-160, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 1.2143, accuracy: 0.001, "only the way past the end gives")

        bench.hand(renders, tree, .ended)
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self)).destination, 1)
    }

    /// A RUN THAT COMES ROUND HAS NO END: past the last target is the first again, a turn on, and a throw there
    /// rests a turn on rather than going back.
    func testARunThatComesRoundHasNoEnd() throws {
        let phase = State(wrappedValue: 6.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node {
            PhaseLayout([1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                handed.phases.append(at)
                return [Placement(Rect(0, 0, 10, 10))]
            }
            .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...7, snaps: .every(1), circular: true)
            .node
        }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.phaseLayout)?.driven?[.phase]?.state)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-120, 0))
        XCTAssertEqual(handed.phases.last ?? 0, 7.2, accuracy: 0.001, "on past the last card, at full speed")
        XCTAssertEqual(phase.wrappedValue, 7, "the first card, a turn on")

        bench.hand(renders, tree, .ended)
        XCTAssertEqual(try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self)).destination, 7)
    }

    /// A layout of one view a hand moves, a hundred points a unit, over `range`, resting on `snaps`.
    private func handTree(
        _ phase: State<Double>, handed: Handed? = nil, range: ClosedRange<Double>, snaps: LayoutPlaces? = .every(1)
    ) -> Node {
        PhaseLayout([1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            handed?.phases.append(at)
            return [Placement(Rect(0, 0, 10, 10))]
        }
        .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: range, snaps: snaps)
        .node
    }

    /// A WHEEL'S NOTCH STEPS THE RUN TO THE NEXT TARGET that way, under the layout's motion - however far apart the
    /// targets stand - and the next notch steps on from where the run is going, not from where it is shown yet.
    func testANotchStepsTheRunToTheNextTarget() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { handTree(phase, range: 0...1, snaps: [0.2, 0.5]) }

        let worn = try XCTUnwrap(bench.laid(renders, tree).patch.first(.phaseLayout)?.driven?[.phase]?.state)

        bench.step(renders, tree, Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 0.2, "a notch moving what is under the hand to the left steps it on")
        let sent = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(sent.destination, 0.2, accuracy: 0.001, "a journey of the phase")
        XCTAssertEqual(sent.value, 0, accuracy: 0.001, "from where it stood")

        bench.step(renders, tree, Point(-2, 0))
        XCTAssertEqual(phase.wrappedValue, 1, "two on from where it is going")

        bench.step(renders, tree, Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 1, "held to the last")

        bench.step(renders, tree, Point(1, 0))
        XCTAssertEqual(phase.wrappedValue, 0.5, "and back")
    }

    /// A RUN THAT COMES ROUND IS STEPPED ROUND: a notch past the last target is the first again, a turn on.
    func testANotchStepsARunThatComesRoundATurnOn() throws {
        let phase = State(wrappedValue: 3.0)
        let renders = Renders()
        func tree() -> Node {
            PhaseLayout([1], phase: phase.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .axis(
                    \.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...4, snaps: .every(1), circular: true)
                .node
        }
        _ = bench.laid(renders, tree)

        bench.step(renders, tree, Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 4, "a turn on, the first again")

        bench.step(renders, tree, Point(2, 0))
        XCTAssertEqual(phase.wrappedValue, 2, "back across the turn")
    }

    /// A HAND HOLDING THE RUN KEEPS IT: a notch meanwhile moves nothing.
    func testANotchLeavesARunTheHandHolds() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { handTree(phase, range: 0...2) }
        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.step(renders, tree, Point(-1, 0))

        XCTAssertEqual(phase.wrappedValue, 0)
    }

    /// A NOTCH MOVES AN AXIS WITH NO SNAPS as far as a hand going a notch's travel would, and no farther than the
    /// range's end.
    func testANotchMovesAnAxisWithNoSnapsANotchsTravel() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { handTree(phase, range: 0...1.5, snaps: nil) }
        _ = bench.laid(renders, tree)

        bench.step(renders, tree, Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 1, accuracy: 0.001, "a hundred points, a unit")

        bench.step(renders, tree, Point(-1, 0))
        XCTAssertEqual(phase.wrappedValue, 1.5, accuracy: 0.001, "held to the end")
    }

    // MARK: - A tap

    /// A TAP LANDS ON THE VIEW ITSELF, with its item, a hand over the layout or none: nothing lies over the views.
    func testATapLandsOnTheViewItself() async throws {
        var heard: [Int] = []
        let renders = Renders()
        let patch = renders.render(
            PhaseLayout([7, 8], phase: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...1, snaps: .every(1))
                .onItemTapped { heard.append($0) }
                .node)
        let layout = try XCTUnwrap(patch.first(.phaseLayout))
        let tap = try XCTUnwrap(layout.children[1].events?[.tapped])

        XCTAssertTrue(renders.fire(tap))
        _ = await settle()

        XCTAssertEqual(heard, [8])
    }
}

