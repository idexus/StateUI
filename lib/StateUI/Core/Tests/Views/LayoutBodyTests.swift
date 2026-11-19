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
        return MotionLayout(shown, parameters: phase.traveling(.none)) { item in
            if let own, item == first {
                Text("\(item)").layoutBody(own)
            } else {
                Text("\(item)")
            }
        } placements: { _, at in
            shown.indices.map { Placement(Rect((Double($0) - at) * 100, 0, 10, 10)) }
        }
        .layoutBodies(bodies)
        .node
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

    // MARK: - What the layout answers

    /// THE LAYOUT ANSWERS EACH VIEW THE BODY THE VIEW SAYS ITSELF, and none for a view that says nothing: its
    /// layout's bodies decide that one, on the host.
    func testTheLayoutAnswersEachViewsOwnBody() {
        let (items, phase) = (State(wrappedValue: [0, 1, 2]), State(wrappedValue: 0.0))
        let own = LayoutBody.followsLayout(Spring(response: .milliseconds(420), damping: 0.6))

        _ = bench.laid(Renders(), { self.row(items, phase: phase, bodies: .onChange(self.quick), own: own) })
        XCTAssertEqual(bench.answer.views.map(\.body), [own, nil, nil])

        _ = bench.laid(Renders(), { self.row(items, phase: phase, bodies: .onChange(self.quick), own: LayoutBody.none) })
        XCTAssertEqual(bench.answer.views.map(\.body), [LayoutBody.none, nil, nil], "a view saying none says so")
    }

    /// WHAT A LAYOUT SAYS FOR EVERY VIEW IS A MEMBER OF ITS CONTRACT, written on its element as any layout's.
    func testALayoutsBodiesAreWrittenOnItsElement() throws {
        let (items, phase) = (State(wrappedValue: [0, 1]), State(wrappedValue: 0.0))
        let renders = Renders()

        let said = renders.render(row(items, phase: phase, bodies: .onChange(quick)))
        let layout = try XCTUnwrap(said.first(.motionLayout))
        XCTAssertEqual(
            layout.properties[LayoutContract.layoutBodies.token].flatMap(LayoutBody.init(propValue:)), .onChange(quick))

        let stack = renders.renderFromScratch(VStack { Text("row") }.layoutBodies(.none).node)
        XCTAssertEqual(
            stack.first(.vStack)?.properties[LayoutContract.layoutBodies.token].flatMap(LayoutBody.init(propValue:)),
            LayoutBody.none)
    }
}
