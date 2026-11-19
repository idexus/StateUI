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

    /// A LAYOUT'S VIEWS ANSWER A CHANGE UNLESS IT SAYS OTHERWISE: with nothing said, each view is answered a body
    /// on the standard spring that follows no moving place.
    func testALayoutsViewsAnswerAChangeUnlessSaidOtherwise() {
        let phase = State(wrappedValue: 0.0)
        _ = bench.laid(Renders(), {
            MotionLayout([0, 1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(0, 0, 10, 10)), Placement(Rect(100, 0, 10, 10))]
            }
            .node
        })

        let standard = HostLayoutBody(milliseconds: 300, damping: 1, follows: false)
        XCTAssertEqual(bench.answer.views.map(\.body), [standard, standard])
    }

    /// A VIEW'S OWN BODY WINS OVER ITS LAYOUT'S, either way: one saying none is answered none among views with a
    /// body, and one saying a body is answered it in a layout whose views have none.
    func testAViewsOwnBodyWinsOverItsLayouts() {
        let (items, phase) = (State(wrappedValue: [0, 1, 2]), State(wrappedValue: 0.0))
        let spring = HostLayoutBody(milliseconds: 160, damping: 1, follows: false)

        _ = bench.laid(Renders(), { self.row(items, phase: phase, bodies: .onChange(self.quick), own: LayoutBody.none) })
        XCTAssertEqual(bench.answer.views.map(\.body), [nil, spring, spring], "its own none among bodies")

        _ = bench.laid(Renders(), { self.row(items, phase: phase, bodies: .none, own: .onChange(self.quick)) })
        XCTAssertEqual(bench.answer.views.map(\.body), [spring, nil, nil], "its own body among none")
    }

    /// A BODY FOLLOWING ITS PLACE IS ANSWERED AS ONE THAT FOLLOWS, on its own spring.
    func testAFollowingBodyIsAnsweredAsFollowing() {
        let (items, phase) = (State(wrappedValue: [0, 1]), State(wrappedValue: 0.0))
        let own = LayoutBody.followsLayout(Spring(response: .milliseconds(420), damping: 0.6))

        _ = bench.laid(Renders(), { self.row(items, phase: phase, bodies: .onChange(self.quick), own: own) })

        XCTAssertEqual(bench.answer.views[0].body, HostLayoutBody(milliseconds: 420, damping: 0.6, follows: true))
        XCTAssertEqual(bench.answer.views[1].body?.follows, false)
    }
}
