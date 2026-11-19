// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// How many times views were built, a class so the views holding it compare it by identity.
private final class Builds {
    var count = 0
}

/// A view of its own for one item, counting its builds.
private struct Tile: View {
    let item: Int
    let builds: Builds

    var body: some View {
        builds.count += 1
        return VStack { Text("tile \(item)") }
    }
}

/// A change of a motion layout's description at the current phase - a view joining or leaving, a new order, a value
/// read in the body - answers the host each view's new place and where its way there is measured to: the phase, the
/// room and a followed state move the views as they always do. Bringing a view onto its place is the host's
/// (`ProgramBodiesTests` in the host layer).
@MainActor
final class LayoutChangeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// The phase of every layout a test builds that moves none.
    private let turn = State(wrappedValue: 0.0)

    /// A row of views, `gap` apart from the left - each one's place its index in the items - every view the body
    /// `bodies`.
    private func row(
        _ items: State<[Int]>, gap: State<Double>? = nil, phase: State<Double>? = nil,
        bodies: LayoutBody = .onChange(Spring(response: .milliseconds(160)))
    ) -> Node {
        let apart = gap?.wrappedValue ?? 100
        let count = items.wrappedValue.count
        return MotionLayout(items.wrappedValue, parameters: (phase ?? turn).projectedValue) { Text("\($0)") } placements: { _, at in
            (0..<count).map { Placement(Rect((Double($0) - at) * apart, 0, 10, 10)) }
        }
        .layoutBodies(bodies)
        .node
    }

    /// What the layout answers its host after `tree` was described again and a cycle ran.
    private func answer(_ renders: Renders, _ tree: () -> Node) -> HostLayoutAnswer {
        _ = renders.render(tree())
        bench.cycle()
        _ = bench.shown(renders.renderFromScratch(tree()))
        return bench.answer
    }

    /// A VIEW LEAVING GOES AT ONCE, AND THE OTHERS ARE ANSWERED THEIR NEW PLACES: each view the change moves is told
    /// where its way is measured to, on the layout's bodies' spring, under a change of its own number.
    func testAViewLeavingAnswersTheOthersTheirNewPlaces() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)
        let stood = bench.answer

        items.wrappedValue = [1, 2]
        let changed = answer(renders, tree)

        XCTAssertEqual(changed.views.count, 2, "the view left at once")
        XCTAssertEqual(changed.views.map(\.key), Array(stood.views.map(\.key).dropFirst()), "the others, as they were")
        XCTAssertEqual(changed.views.map(\.target.bounds.x), [0, 100])
        XCTAssertEqual(changed.views.map { $0.discrete?.bounds.x }, [0, 100], "where each one's way is measured to")
        XCTAssertNotEqual(changed.change, stood.change, "a change of its own")
    }

    /// A VIEW JOINING IS ANSWERED ITS PLACE, the others no change at all.
    func testAViewJoiningIsAnsweredItsPlace() {
        let items = State(wrappedValue: [0, 1])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [0, 1, 2]
        let changed = answer(renders, tree)

        XCTAssertEqual(changed.views[2].discrete?.bounds.x, 200, "where it goes")
        XCTAssertNil(changed.views[0].discrete, "the others stand")
        XCTAssertNil(changed.views[1].discrete)
    }

    /// A NEW ORDER BUILDS NO VIEW AGAIN: each item's view of its own, built with the same inputs under the same
    /// identity, is carried to its new place.
    func testANewOrderBuildsNoViewAgain() {
        let (items, builds, renders) = (State(wrappedValue: [0, 1, 2]), Builds(), Renders())
        func tree() -> Node {
            let count = items.wrappedValue.count
            return MotionLayout(items.wrappedValue, parameters: turn.projectedValue) { Tile(item: $0, builds: builds) } placements: { _, _ in
                (0..<count).map { Placement(Rect(Double($0) * 100, 0, 10, 10)) }
            }
            .node
        }
        _ = bench.laid(renders, tree)
        XCTAssertEqual(builds.count, 3)

        items.wrappedValue = [2, 0, 1]
        _ = renders.render(tree())
        XCTAssertEqual(builds.count, 3, "carried, not built again")
    }

    /// A NEW ORDER DESCRIBES NO HOLDER AGAIN: with no shade and no tap, each view's holder is a view of its own,
    /// carried whole to its new place.
    func testANewOrderDescribesNoHolderAgain() {
        let (items, builds, renders) = (State(wrappedValue: [0, 1, 2]), Builds(), Renders())
        func tree() -> Node {
            let count = items.wrappedValue.count
            return MotionLayout(items.wrappedValue, parameters: turn.projectedValue) { Tile(item: $0, builds: builds) } placements: { _, _ in
                (0..<count).map { Placement(Rect(Double($0) * 100, 0, 10, 10)) }
            }
            .node
        }
        _ = bench.laid(renders, tree)
        let holders = renders.builds(of: "LayoutItemView")
        XCTAssertEqual(holders.count, 3)

        items.wrappedValue = [2, 0, 1]
        _ = renders.render(tree())
        XCTAssertEqual(renders.builds(of: "LayoutItemView").reduce(0, +), holders.reduce(0, +), "carried whole")
    }

    /// A NEW ORDER ANSWERS EACH VIEW ITS NEW PLACE, the view its item's own whatever its place among the views.
    func testANewOrderAnswersEachViewItsNewPlace() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)
        let keys = bench.answer.views.map(\.key)

        items.wrappedValue = [2, 1, 0]
        let changed = answer(renders, tree)

        XCTAssertEqual(changed.views.map(\.key), keys.reversed(), "each item's own key, in the new order")
        XCTAssertEqual(changed.views.map { $0.discrete?.bounds.x }, [0, nil, 200], "the two that changed places")
    }

    /// A VALUE READ IN THE BODY IS A CHANGE OF THE DESCRIPTION: the new places are answered as a change.
    func testAValueReadInTheBodyIsAChange() {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap) }
        _ = bench.laid(renders, tree)
        let stood = bench.answer.change

        gap.wrappedValue = 50
        let changed = answer(renders, tree)

        XCTAssertEqual(changed.views[2].discrete?.bounds.x, 100)
        XCTAssertNotEqual(changed.change, stood)
    }

    /// A CHANGE WHILE THE PHASE TRAVELS LEAVES THE PHASE ITS OWN MOVE: the change is measured at the phase the run
    /// last stood at, and the phase moving on is no change.
    func testAChangeWhileThePhaseTravelsLeavesThePhaseItsMove() throws {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap, phase: phase) }
        let laid = bench.laid(renders, tree)
        let worn = try XCTUnwrap(laid.patch.first(.motionLayout)?.driven?[.parameters]?.state)

        moved(worn, to: 0.5)
        bench.cycle()
        gap.wrappedValue = 50
        let changed = answer(renders, tree)
        XCTAssertEqual(try XCTUnwrap(changed.views[2].discrete).bounds.x, 75, accuracy: 0.001, "(2 - 0.5) × 50")

        moved(worn, to: 1)
        bench.cycle()
        XCTAssertEqual(bench.answer.views[2].target.bounds.x, 50, accuracy: 0.001, "(2 - 1) × 50: the phase's own move")
        XCTAssertEqual(bench.answer.change, changed.change, "which is no change of the layout")
    }

    /// A CHANGE CHANGED AGAIN IS A CHANGE OF ITS OWN: each has its number, so the host sets its views out anew.
    func testAChangeChangedAgainIsAChangeOfItsOwn() {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap) }
        _ = bench.laid(renders, tree)

        gap.wrappedValue = 50
        let first = answer(renders, tree)
        gap.wrappedValue = 100
        let second = answer(renders, tree)

        XCTAssertNotEqual(second.change, first.change)
        XCTAssertEqual(second.views[2].discrete?.bounds.x, 200)
    }

    /// A RENDER THAT CHANGES NOTHING MOVES NOTHING: the same arithmetic described again shows the same run.
    func testARenderThatChangesNothingMovesNothing() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        let before = bench.laid(renders, tree).run
        let stood = bench.answer.change

        let again = answer(renders, tree)

        XCTAssertEqual(bench.placed, before)
        XCTAssertEqual(again.change, stood, "no change of the layout")
        XCTAssertEqual(again.views.map(\.discrete), [nil, nil, nil])
    }

    /// A NEW PLACE THE MOTION SET OUT FROM IS A CHANGE: arithmetic that reads it is answered anew where the run
    /// stood, as a change of the layout.
    func testANewSetOutIsAChange() throws {
        let phase = State(wrappedValue: 1.0)
        let renders = Renders()
        func tree() -> Node {
            MotionLayout([0], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _, from in [Placement(Rect(from * 100, 0, 10, 10))] }
                .axis(\.self, input: .scroll(.horizontal, lengthPerUnit: 100), range: 0...3, snaps: .every(1))
                .layoutBodies(.onChange(Spring(response: .milliseconds(160))))
                .node
        }
        _ = bench.laid(renders, tree)
        let stood = bench.answer

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-120, 0))
        bench.cycle()

        XCTAssertEqual(stood.views[0].target.bounds.x, 100, accuracy: 0.001, "where it stood")
        XCTAssertEqual(bench.answer.views[0].target.bounds.x, 200, accuracy: 0.001, "where it sets out from now")
        XCTAssertEqual(try XCTUnwrap(bench.answer.views[0].discrete).bounds.x, 200, accuracy: 0.001)
        XCTAssertNotEqual(bench.answer.change, stood.change)
    }

    /// A NEW ROOM TRAVELS NOT: the layout follows the window at once.
    func testANewRoomTravelsNot() throws {
        let renders = Renders()
        let items = State(wrappedValue: [0, 1])
        func tree() -> Node {
            MotionLayout(items.wrappedValue, parameters: turn.projectedValue) { Text("\($0)") } placements: { context, _ in
                [Placement(Rect(0, 0, context.bounds.width, 10)), Placement(Rect(context.bounds.width, 0, 10, 10))]
            }
            .layoutBodies(.onChange(Spring(response: .milliseconds(160))))
            .node
        }
        _ = bench.laid(renders, tree)
        let stood = bench.answer.change

        bench.room(500, 200)
        bench.cycle()

        XCTAssertEqual(bench.answer.views[1].target.bounds.x, 500)
        XCTAssertEqual(bench.answer.change, stood, "a new room is no change of the layout")
        XCTAssertNil(bench.answer.views[1].discrete, "so no view's way is measured anew")
    }
}
