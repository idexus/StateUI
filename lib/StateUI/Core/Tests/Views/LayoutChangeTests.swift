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

/// A change of a phase layout's description at the current phase - a view joining or leaving, a new order, a value
/// read in the body - travels under the layout's motion from where each view was shown: the phase, the room and a
/// followed state move the views as they always do.
@MainActor
final class LayoutChangeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// The phase of every layout a test builds that moves none.
    private let turn = State(wrappedValue: 0.0)

    /// A row of views, `gap` apart from the left - each one's place its index in the items - under `motion`.
    private func row(
        _ items: State<[Int]>, gap: State<Double>? = nil, phase: State<Double>? = nil,
        motion: Motion = .eased(.milliseconds(160), .linear)
    ) -> Node {
        let apart = gap?.wrappedValue ?? 100
        let count = items.wrappedValue.count
        return PhaseLayout(items.wrappedValue, phase: (phase ?? turn).projectedValue) { Text("\($0)") } placements: { _, at in
            (0..<count).map { Placement(Rect((Double($0) - at) * apart, 0, 10, 10)) }
        }
        .motion(motion)
        .node
    }

    /// The run shown after `frames` frames.
    private func after(_ frames: Int, _ renders: Renders, _ tree: () -> Node) -> [Placement] {
        for _ in 0..<frames { bench.cycle() }
        return bench.shown(renders.renderFromScratch(tree()))
    }

    /// A VIEW LEAVING GOES AT ONCE, AND THE OTHERS CLOSE UP from where they stood, under the layout's motion.
    func testTheOthersCloseUpUnderTheMotion() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [1, 2]
        _ = renders.render(tree())

        let first = after(1, renders, tree)
        XCTAssertEqual(first.count, 2, "the view left at once")
        XCTAssertEqual(first[0].bounds.x, 100, accuracy: 0.001, "where it stood")
        XCTAssertEqual(after(5, renders, tree)[0].bounds.x, 50, accuracy: 0.001, "on its way, as the motion goes")
        XCTAssertEqual(after(5, renders, tree)[0].bounds.x, 0, accuracy: 0.001, "where its arithmetic puts it")
    }

    /// A LAYOUT SAYING NO LAW OF ITS OWN TAKES THE APPLICATION'S, as the host's channel does - one answer to
    /// `.inherited` everywhere: an application that turned motion off sees a change land at once.
    func testALayoutWithNoLawOfItsOwnTakesTheApplications() {
        StandardEnvironment.application.motion = .none
        defer { StandardEnvironment.application.motion = .standard }
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items, motion: .inherited) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [1, 2]
        _ = renders.render(tree())

        XCTAssertEqual(after(1, renders, tree)[0].bounds.x, 0, accuracy: 0.001, "no motion: where its arithmetic puts it")
    }

    /// A VIEW JOINING FADES IN where its arithmetic puts it.
    func testAViewJoiningFadesIn() {
        let items = State(wrappedValue: [0, 1])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [0, 1, 2]
        _ = renders.render(tree())

        let first = after(1, renders, tree)
        XCTAssertEqual(first[2].bounds.x, 200, accuracy: 0.001, "where it goes")
        XCTAssertEqual(first[2].opacity, 0, accuracy: 0.001, "none of it yet")
        XCTAssertEqual(after(5, renders, tree)[2].opacity, 0.5, accuracy: 0.001)
        XCTAssertEqual(after(5, renders, tree)[2].opacity, 1, accuracy: 0.001)
        XCTAssertEqual(first[0].opacity, 1, "the others as they were")
    }

    /// A NEW ORDER BUILDS NO VIEW AGAIN: each item's view of its own, built with the same inputs under the same
    /// identity, is carried to its new place.
    func testANewOrderBuildsNoViewAgain() {
        let (items, builds, renders) = (State(wrappedValue: [0, 1, 2]), Builds(), Renders())
        func tree() -> Node {
            let count = items.wrappedValue.count
            return PhaseLayout(items.wrappedValue, phase: turn.projectedValue) { Tile(item: $0, builds: builds) } placements: { _, _ in
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
            return PhaseLayout(items.wrappedValue, phase: turn.projectedValue) { Tile(item: $0, builds: builds) } placements: { _, _ in
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

    /// A NEW ORDER SLIDES: each view from where it stood to its new place.
    func testANewOrderSlides() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [2, 1, 0]
        _ = renders.render(tree())

        let first = after(1, renders, tree)
        XCTAssertEqual(first.map(\.bounds.x), [200, 100, 0], "each where it stood")
        XCTAssertEqual(after(10, renders, tree).map(\.bounds.x), [0, 100, 200])
    }

    /// A VALUE READ IN THE BODY IS A CHANGE OF THE DESCRIPTION, and the new poses travel.
    func testAValueReadInTheBodyTravels() {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap) }
        _ = bench.laid(renders, tree)

        gap.wrappedValue = 50
        _ = renders.render(tree())

        XCTAssertEqual(after(1, renders, tree)[2].bounds.x, 200, accuracy: 0.001)
        XCTAssertEqual(after(10, renders, tree)[2].bounds.x, 100, accuracy: 0.001)
    }

    /// A CHANGE WHILE THE PHASE TRAVELS LEAVES THE PHASE ITS OWN MOVE: the change is measured at the phase it was
    /// shown at, so each frame shows the phase where it is, the change on its way.
    func testAChangeWhileThePhaseTravelsLeavesThePhaseItsMove() throws {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap, phase: phase) }
        let laid = bench.laid(renders, tree)
        let worn = try XCTUnwrap(laid.patch.first(.phaseLayout)?.driven?[.phase]?.state)

        moved(worn, to: 0.5)
        bench.cycle()
        gap.wrappedValue = 50
        _ = renders.render(tree())

        let first = after(1, renders, tree)
        XCTAssertEqual(first[2].bounds.x, 150, accuracy: 0.001, "(2 - 0.5) × 100, where it stood")
        moved(worn, to: 1)
        XCTAssertEqual(after(10, renders, tree)[2].bounds.x, 50, accuracy: 0.001, "(2 - 1) × 50: the phase's, the change's")
    }

    /// A CHANGE ON ITS WAY, CHANGED AGAIN, sets out from where each view is shown, at the speed it had.
    func testAChangeChangedAgainSetsOutFromWhereItIsShown() {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap) }
        _ = bench.laid(renders, tree)

        gap.wrappedValue = 50
        _ = renders.render(tree())
        let halfway = after(6, renders, tree)[2].bounds.x

        gap.wrappedValue = 100
        _ = renders.render(tree())

        XCTAssertEqual(after(1, renders, tree)[2].bounds.x, halfway, accuracy: 2, "no jump back")
        XCTAssertEqual(after(20, renders, tree)[2].bounds.x, 200, accuracy: 0.001)
    }

    /// LESS MOTION SHOWS A CHANGE AT ONCE, and a layout whose motion is none.
    func testLessMotionShowsAChangeAtOnce() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [1, 2]
        _ = renders.render(tree())
        bench.cycle(reducesMotion: true)

        XCTAssertEqual(bench.shown(renders.renderFromScratch(tree()))[0].bounds.x, 0)

        let still = State(wrappedValue: [0, 1, 2])
        let others = Renders()
        func plain() -> Node { row(still, motion: .none) }
        _ = bench.laid(others, plain)
        still.wrappedValue = [1, 2]
        _ = others.render(plain())

        XCTAssertEqual(after(1, others, plain)[0].bounds.x, 0)
    }

    /// A RENDER THAT CHANGES NOTHING MOVES NOTHING: the same arithmetic described again shows the same run.
    func testARenderThatChangesNothingMovesNothing() {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        let before = bench.laid(renders, tree).run

        _ = renders.renderFromScratch(tree())

        XCTAssertEqual(after(1, renders, tree), before)
    }

    /// A NEW SET-OUT TRAVELS AS A CHANGE DOES: what an arithmetic draws from where the motion set out goes from where
    /// it was shown as the hand passes a target and the motion sets out from there.
    func testANewSetOutTravels() throws {
        let phase = State(wrappedValue: 1.0)
        let renders = Renders()
        func tree() -> Node {
            PhaseLayout([0], phase: phase.projectedValue) { Text("\($0)") } placements: { _, _, from in [Placement(Rect(from * 100, 0, 10, 10))] }
                .axis(\.self, input: .scroll(.horizontal, pointsPerUnit: 100), range: 0...3, snaps: .every(1))
                .motion(.eased(.milliseconds(160), .linear))
                .node
        }
        _ = bench.laid(renders, tree)

        bench.hand(renders, tree, .began)
        bench.hand(renders, tree, .changed, moved: Point(-120, 0))

        XCTAssertEqual(after(0, renders, tree)[0].bounds.x, 100, accuracy: 0.001, "where it was shown")
        XCTAssertEqual(after(10, renders, tree)[0].bounds.x, 200, accuracy: 0.001, "where it sets out from now")
    }

    /// A NEW ROOM TRAVELS NOT: the layout follows the window at once.
    func testANewRoomTravelsNot() throws {
        let renders = Renders()
        let items = State(wrappedValue: [0, 1])
        func tree() -> Node {
            PhaseLayout(items.wrappedValue, phase: turn.projectedValue) { Text("\($0)") } placements: { room, _ in
                [Placement(Rect(0, 0, room.width, 10)), Placement(Rect(room.width, 0, 10, 10))]
            }
            .motion(.eased(.milliseconds(160), .linear))
            .node
        }
        let laid = bench.laid(renders, tree)
        let fed = try XCTUnwrap(laid.patch.first(.phaseLayout)?.driven?[.frame]?.state)

        moved(fed, to: [10, 20, 500, 200])

        XCTAssertEqual(after(1, renders, tree)[1].bounds.x, 500)
    }
}
