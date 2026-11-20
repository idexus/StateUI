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

/// A change of a motion layout's description - a view joining or leaving, a new order, a value read in the body -
/// is another program, which answers each view under its item's own key at its new place, and builds no view
/// again. Measuring each view's way by those keys, and bringing it there, is the host's (`ProgramAskingTests` and
/// `ProgramBodiesTests` in the host layer).
@MainActor
final class LayoutChangeTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// The phase of every layout a test builds, which moves none.
    private let turn = State(wrappedValue: 0.0)

    /// A row of views, `gap` apart from the left - each one's place its index in the items.
    private func row(_ items: State<[Int]>, gap: State<Double>? = nil) -> Node {
        let apart = gap?.wrappedValue ?? 100
        let count = items.wrappedValue.count
        return MotionLayout(items.wrappedValue, parameters: turn.projectedValue) { Text("\($0)") } placements: { _, at in
            (0..<count).map { Placement(Rect(x: (Double($0) - at) * apart, y: 0, width: 10, height: 10)) }
        }
        .node
    }

    /// The program the host is handed once `tree` is described again, and what it answers.
    private func described(
        _ renders: Renders, _ tree: () -> Node, file: StaticString = #filePath, line: UInt = #line
    ) throws -> (program: HostLayoutProgram, answer: HostLayoutAnswer) {
        let program = try XCTUnwrap(bench.takes(renders.render(tree())), "no program handed", file: file, line: line)
        bench.cycle()
        return (program, bench.answer)
    }

    /// A VIEW LEAVING IS GONE FROM THE ANSWER, AND THE OTHERS ARE ANSWERED THEIR NEW PLACES under the keys they had.
    func testAViewLeavingAnswersTheOthersTheirNewPlaces() throws {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)
        let stood = bench.answer

        items.wrappedValue = [1, 2]
        let changed = try described(renders, tree).answer

        XCTAssertEqual(changed.views.map(\.key), Array(stood.views.map(\.key).dropFirst()), "the others, as they were")
        XCTAssertEqual(changed.views.map(\.target.bounds.x), [0, 100])
    }

    /// A VIEW JOINING IS ANSWERED ITS PLACE under a key of its own, the others as they were.
    func testAViewJoiningIsAnsweredItsPlace() throws {
        let items = State(wrappedValue: [0, 1])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)
        let stood = bench.answer

        items.wrappedValue = [0, 1, 2]
        let changed = try described(renders, tree).answer

        XCTAssertEqual(Array(changed.views.prefix(2)), stood.views, "the others stand")
        XCTAssertEqual(changed.views[2].target.bounds.x, 200, "where it goes")
        XCTAssertFalse(stood.views.map(\.key).contains(changed.views[2].key), "a view of its own")
    }

    /// A NEW ORDER BUILDS NO VIEW AGAIN: each item's view of its own, built with the same inputs under the same
    /// identity, is carried to its new place.
    func testANewOrderBuildsNoViewAgain() {
        let (items, builds, renders) = (State(wrappedValue: [0, 1, 2]), Builds(), Renders())
        func tree() -> Node {
            let count = items.wrappedValue.count
            return MotionLayout(items.wrappedValue, parameters: turn.projectedValue) { Tile(item: $0, builds: builds) } placements: { _, _ in
                (0..<count).map { Placement(Rect(x: Double($0) * 100, y: 0, width: 10, height: 10)) }
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
                (0..<count).map { Placement(Rect(x: Double($0) * 100, y: 0, width: 10, height: 10)) }
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
    func testANewOrderAnswersEachViewItsNewPlace() throws {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        _ = bench.laid(renders, tree)
        let keys = bench.answer.views.map(\.key)

        items.wrappedValue = [2, 1, 0]
        let changed = try described(renders, tree).answer

        XCTAssertEqual(changed.views.map(\.key), keys.reversed(), "each item's own key, in the new order")
        XCTAssertEqual(changed.views.map(\.target.bounds.x), [0, 100, 200], "each at the place its new order gives")
    }

    /// A VALUE READ IN THE BODY IS ANOTHER DESCRIPTION: another program, which answers the new places.
    func testAValueReadInTheBodyIsAnotherDescription() throws {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let renders = Renders()
        func tree() -> Node { row(items, gap: gap) }
        _ = bench.laid(renders, tree)
        let (stood, keys) = (try XCTUnwrap(bench.program), bench.answer.views.map(\.key))

        gap.wrappedValue = 50
        let changed = try described(renders, tree)

        XCTAssertEqual(changed.program.slot, stood.slot, "the same layout")
        XCTAssertNotEqual(changed.program.revision, stood.revision, "described anew")
        XCTAssertEqual(changed.answer.views.map(\.key), keys, "the same views")
        XCTAssertEqual(changed.answer.views.map(\.target.bounds.x), [0, 50, 100])
    }

    /// A RENDER THAT CHANGES NOTHING MOVES NOTHING: the same arithmetic described again answers the same views at
    /// the same places.
    func testARenderThatChangesNothingMovesNothing() throws {
        let items = State(wrappedValue: [0, 1, 2])
        let renders = Renders()
        func tree() -> Node { row(items) }
        let before = bench.laid(renders, tree).run
        let stood = bench.answer

        let again = try described(renders, tree).answer

        XCTAssertEqual(bench.placed, before)
        XCTAssertEqual(again, stood)
    }
}
