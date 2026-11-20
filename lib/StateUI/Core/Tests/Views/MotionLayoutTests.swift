// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A motion layout: what its arithmetic is handed, where the run puts each child, how the program and the hand move
// the phase, and what it says of an answer it cannot use. The gallery's tests hold the hand at full length.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class MotionLayoutTests: XCTestCase {
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
        let turn = State(wrappedValue: 0.0)
        let layout = MotionLayout([1, 2], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in [] }
            .interaction(
                .value(turn.projectedValue, input: .translation(.horizontal, unit: .frontItem)).range(0...1))

        XCTAssertEqual(layout.walkedParts.map(\.label), Mirror(reflecting: layout).children.map { $0.label ?? "" })
    }

    /// `.motion` ON THE LAYOUT IS EVERY VIEW'S OWN, before a common modifier or after it: the parameters' law is
    /// their state's alone.
    func testMotionOnTheLayoutIsEveryViewsOwnInAnyOrder() {
        let layout = MotionLayout([1], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }

        let first = layout.motion(.none).height(200)
        let last = layout.height(200).motion(.none)

        XCTAssertEqual(first.node.motion?.base, .some(Motion.none), "the view's own motion, written first")
        XCTAssertEqual(last.node.motion?.base, .some(Motion.none), "the view's own motion, written last")
    }

    /// A SLOT IS ITS ITEM'S OWN IDENTITY, compared as the value it is and numbered by the layout: two identities
    /// that describe alike - a class prints its type's name - are two slots, an identity keeps its number while it
    /// stands, a new one takes a number never given, and naming one spells nothing.
    func testASlotIsItsItemsOwnIdentity() {
        let tags = [Tag(1), Tag(2)]
        let layout = MotionLayout(tags, parameters: State(wrappedValue: 0.0).projectedValue) { _ in
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
            MotionLayout([1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { context, phase in
                handed.rooms.append(context.bounds)
                handed.phases.append(phase)
                return [Placement(Rect(x: 0, y: 0, width: 10, height: 10)), Placement(Rect(x: 20, y: 0, width: 10, height: 10))]
            }
            .node
        })

        XCTAssertEqual(handed.rooms.last, Rect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(handed.phases.last, 0)
    }

    /// THE VIEWS ALONE, IN THE ITEMS' ORDER: a hand lays nothing over them.
    func testTheRunPlacesTheViewsAlone() {
        let turn = State(wrappedValue: 0.0)
        let (_, run) = bench.laid(Renders(), {
            MotionLayout([1, 2], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 10, height: 10), zIndex: 5), Placement(Rect(x: 20, y: 0, width: 10, height: 10))]
            }
            .interaction(
                .value(turn.projectedValue, input: .translation(.horizontal, unit: .points(100)))
                    .reversed(true).range(0...1).snaps(.every(1)))
            .node
        })

        XCTAssertEqual(run.map(\.bounds), [Rect(x: 0, y: 0, width: 10, height: 10), Rect(x: 20, y: 0, width: 10, height: 10)])
    }

    /// THE HAND IS HEARD ON THE ELEMENT ITSELF, over every view: what it moves, and which way, is the element's own
    /// program.
    func testTheHandIsHeardOnTheElementItself() throws {
        let turn = State(wrappedValue: 0.0)
        let patch = Renders().render(
            MotionLayout([1], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(x: 0, y: 0, width: 10, height: 10))] }
                .interaction(
                    .value(turn.projectedValue, input: .translation(.vertical, unit: .points(100)))
                        .reversed(true).range(0...1).snaps(.every(1)))
                .node)
        let layout = try XCTUnwrap(patch.first(.motionLayout))

        XCTAssertEqual(layout.moved.map(\.input), [.translation(.vertical, unit: .points(100), swipes: false)])
        XCTAssertNil(patch.first(.scrollView), "nothing scrolls under the hand")
    }

    /// A LAYOUT PLACES AS WRITTEN UNLESS IT MIRRORS RIGHT TO LEFT: the element says so only where the author asks.
    func testAAxisValuesAsWrittenUnlessItMirrorsRightToLeft() throws {
        func layout(_ mirrors: Bool?) throws -> HostPatch {
            var layout = MotionLayout([1], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
            }
            if let mirrors { layout = layout.mirrorsRightToLeft(mirrors) }
            return try XCTUnwrap(Renders().render(layout.node).first(.motionLayout))
        }

        XCTAssertNil(try layout(nil).props[.mirrorsRightToLeft], "as written")
        XCTAssertNil(try layout(false).props[.mirrorsRightToLeft], "as written")
        XCTAssertEqual(try layout(true).props[.mirrorsRightToLeft], .bool(true))
    }

    /// AN ANSWER OF THE WRONG LENGTH IS SAID AND MADE TO FIT: one placement a view, the rest at the top left.
    func testAnAnswerOfTheWrongLengthIsSaidAndMadeToFit() {
        let (_, run) = bench.laid(Renders(), {
            MotionLayout([1, 2, 3], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(x: 5, y: 5, width: 10, height: 10))] }.node
        })

        XCTAssertEqual(run.prefix(3).map(\.bounds), [Rect(x: 5, y: 5, width: 10, height: 10), .zero, .zero])
        XCTAssertTrue(hasComplained("placements answered 1 placements for 3 views"))
    }

    /// A NUMBER THAT IS NOT FINITE IS SAID AND STANDS NEUTRAL: an answer the arithmetic got wrong - a division by
    /// nothing, an infinity - reaches no host; each such number is the one a placement at the top left holds.
    func testANumberThatIsNotFiniteIsSaidAndStandsNeutral() {
        var turned = Placement(Rect(x: 5, y: .nan, width: .infinity, height: 10))
        turned.opacity = .nan
        let placed = turned
        let (_, run) = bench.laid(Renders(), {
            MotionLayout([1], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [placed] }.node
        })

        XCTAssertEqual(run.first?.bounds, Rect(x: 5, y: 0, width: 0, height: 10))
        XCTAssertEqual(run.first?.opacity, 1)
        XCTAssertTrue(hasComplained("A MotionLayout's placements answered a number that is not finite"))
    }

    // MARK: - The phase

    /// THE LAYOUT'S ELEMENT WEARS ITS PHASE, both ways, so the host walks it under the layout's motion and says where
    /// it stands every frame: what makes a move of the phase travel, and an awaited one arrive.
    func testTheLayoutsElementWearsItsPhase() async throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _ in [Placement(Rect(x: 0, y: 0, width: 10, height: 10))] }
                .node
        }

        let (patch, _) = bench.laid(renders, tree)
        let worn = try XCTUnwrap(patch.first(.motionLayout)?.driven?[.parameters])

        XCTAssertEqual(worn.mode, .inOut)
        XCTAssertEqual(worn.kind, .property)

        phase.wrappedValue = 2
        bench.cycle()
        XCTAssertEqual(try XCTUnwrap(standing(worn.state, as: JourneyLanes<Double>.self)).destination, 2,
                       "the phase written is where the host walks it")
    }

    /// WITHOUT A HAND THE PHASE TRAVELS AS THE HOST WALKS IT: a write is where the run goes, and the arithmetic is
    /// handed each frame where the host says the phase stands - never the destination at once.
    func testWithoutAHandThePhaseTravelsAsTheHostWalksIt() async throws {
        let handed = Handed()
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, phase in
                handed.phases.append(phase)
                return [Placement(Rect(x: phase * 10, y: 0, width: 10, height: 10))]
            }
            .node
        }

        let (patch, _) = bench.laid(renders, tree)
        let worn = try XCTUnwrap(patch.first(.motionLayout)?.driven?[.parameters]?.state)

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

    /// A layout of one view a hand moves, a hundred points a unit, over `range`, resting on `snaps`.
    private func handTree(
        _ phase: State<Double>, handed: Handed? = nil, range: ClosedRange<Double>, snaps: AxisValues? = .every(1)
    ) -> Node {
        MotionLayout([1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
            handed?.phases.append(at)
            return [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
        }
        .interaction(
            .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(range).snaps(snaps)
                .release(.projected(.eased(.milliseconds(400)))))
        .node
    }

    // MARK: - A tap

    /// A TAP LANDS ON THE VIEW ITSELF, with its item, a hand over the layout or none: nothing lies over the views.
    func testATapLandsOnTheViewItself() async throws {
        var heard: [Int] = []
        let renders = Renders()
        let turn = State(wrappedValue: 0.0)
        let patch = renders.render(
            MotionLayout([7, 8], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .interaction(
                    .value(turn.projectedValue, input: .translation(.horizontal, unit: .points(100)))
                        .reversed(true).range(0...1).snaps(.every(1)))
                .onItemActivated { heard.append($0) }
                .node)
        let layout = try XCTUnwrap(patch.first(.motionLayout))
        let tap = try XCTUnwrap(layout.children[1].events?[.tapped])

        XCTAssertTrue(renders.fire(tap))
        _ = await settle()

        XCTAssertEqual(heard, [8])
    }

    /// EVERY HANDLER OF A TAP RUNS, in the order written.
    func testEveryHandlerOfATapRunsInWritingOrder() async throws {
        var heard: [String] = []
        let renders = Renders()
        let patch = renders.render(
            MotionLayout([7, 8], parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .onItemActivated { heard.append("\($0) first") }
                .onItemActivated(policy: .runConcurrently) { heard.append("\($0) second") }
                .node)
        let tap = try XCTUnwrap(patch.first(.motionLayout)?.children[1].events?[.tapped])

        XCTAssertTrue(renders.fire(tap))
        _ = await settle()

        XCTAssertEqual(heard, ["8 first", "8 second"])
    }
}

