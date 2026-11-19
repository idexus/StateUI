// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How a view comes onto the place its layout gives it: no body, a body answering a change, a body following its
// place - said for every view of a layout, and by a view for itself, which wins.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class LayoutBodyTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    private let quick = Spring(response: .milliseconds(160))

    /// A row of views a hundred points apart, moved a hundred points a unit of `phase` - every view the body
    /// `bodies`, but the first of `items`, which is `own` where one is given.
    private func row(
        _ items: State<[Int]>, phase: State<Double>, bodies: LayoutBody, own: LayoutBody? = nil
    ) -> Node {
        let shown = items.wrappedValue
        let first = shown.first
        return MotionLayout(shown, parameters: phase.projectedValue) { item in
            if let own, item == first {
                Text("\(item)").layoutBody(own)
            } else {
                Text("\(item)")
            }
        } placements: { _, at in
            shown.indices.map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
        }
        .parameterMotion(.none)
        .layoutBodies(bodies)
        .node
    }

    /// The run shown one frame after `tree` was described again.
    private func next(_ renders: Renders, _ tree: () -> Node) -> [Placement] {
        _ = renders.render(tree())
        bench.cycle()
        return bench.shown(renders.renderFromScratch(tree()))
    }

    // MARK: - The value

    /// THE THREE BODIES CROSS TO THE HOST AND BACK AS THEY ARE; numbers that are no body are none.
    func testABodyCrossesAsItIs() throws {
        for body in [LayoutBody.none, .onChange(), .onChange(quick), .followsLayout(Spring(damping: 0.6))] {
            XCTAssertEqual(try XCTUnwrap(LayoutBody(propValue: body.propValue)), body)
        }
        XCTAssertNotEqual(LayoutBody.onChange(quick), .followsLayout(quick), "which body it is, not its spring alone")
        XCTAssertNil(LayoutBody(propValue: .numbers([3, 300, 1])))
        XCTAssertNil(LayoutBody(propValue: .numbers([1, 300])))
        XCTAssertNil(LayoutBody(propValue: .numbers([])))
    }

    /// NO BODY HAS NO SPRING AND FOLLOWS NOTHING; a body answering a change follows nothing either.
    func testWhichBodyFollows() {
        XCTAssertNil(LayoutBody.none.spring)
        XCTAssertFalse(LayoutBody.none.follows)
        XCTAssertFalse(LayoutBody.onChange().follows)
        XCTAssertTrue(LayoutBody.followsLayout().follows)
    }

    // MARK: - A change of the layout

    /// A LAYOUT'S VIEWS ANSWER A CHANGE UNLESS IT SAYS OTHERWISE: with nothing said, a view the others close up on
    /// travels to its new place.
    func testALayoutsViewsAnswerAChangeUnlessSaidOtherwise() {
        let (items, phase) = (State(wrappedValue: [0, 1, 2]), State(wrappedValue: 0.0))
        let renders = Renders()
        func tree() -> Node {
            let shown = items.wrappedValue
            return MotionLayout(shown, parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _ in
                shown.indices.map { Placement(Rect(Double($0) * 100, 0, 10, 10)) }
            }
            .node
        }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [1, 2]
        let first = next(renders, tree)

        XCTAssertEqual(first[0].bounds.x, 100, accuracy: 0.001, "from where it stood")
    }

    /// A VIEW SAYING NO BODY STANDS AT ITS NEW PLACE AT ONCE, while the layout's other views travel to theirs.
    func testAViewWithNoBodyLandsWhileTheOthersTravel() {
        let (items, phase) = (State(wrappedValue: [0, 1, 2]), State(wrappedValue: 0.0))
        let renders = Renders()
        func tree() -> Node { row(items, phase: phase, bodies: .onChange(quick), own: LayoutBody.none) }
        _ = bench.laid(renders, tree)

        // The first view leaves: 1 is first now and says no body, 2 keeps the layout's.
        items.wrappedValue = [1, 2]
        let shown = next(renders, tree)

        XCTAssertEqual(shown[0].bounds.x, 0, accuracy: 0.001, "no body: at its place at once")
        XCTAssertEqual(shown[1].bounds.x, 200, accuracy: 0.001, "a body: from where it stood")
    }

    /// A VIEW'S OWN BODY WINS OVER ITS LAYOUT'S: in a layout whose views have none, the view that says one travels.
    func testAViewsOwnBodyWinsOverItsLayouts() {
        let (items, phase) = (State(wrappedValue: [0, 1, 2]), State(wrappedValue: 0.0))
        let renders = Renders()
        func tree() -> Node { row(items, phase: phase, bodies: .none, own: .onChange(quick)) }
        _ = bench.laid(renders, tree)

        items.wrappedValue = [1, 2]
        let shown = next(renders, tree)

        XCTAssertEqual(shown[0].bounds.x, 100, accuracy: 0.001, "its own body: from where it stood")
        XCTAssertEqual(shown[1].bounds.x, 100, accuracy: 0.001, "the layout's none: at its place at once")
    }
}
