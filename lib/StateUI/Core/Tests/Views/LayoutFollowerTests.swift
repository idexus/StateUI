// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A view of a motion layout following its place as a body: the layout answers the host which views follow, on
/// which spring, as each view's own closure says now. The lag itself is the host's (`ProgramPresentationTests`).
@MainActor
final class LayoutFollowerTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private let bench = LayoutBench()

    /// Two views a hundred apart a unit of the phase: the first following its place, the second the world's own.
    private func tree(_ phase: State<Double>) -> Node {
        MotionLayout([0, 1], parameters: phase.projectedValue) { index in
            if index == 0 {
                Text("\(index)").layoutBody(.followsLayout(Spring(response: .milliseconds(400), damping: 0.5)))
            } else {
                Text("\(index)")
            }
        } placements: { _, at in
            [Placement(Rect(at * 100, 0, 10, 10)), Placement(Rect(at * 100, 20, 10, 10))]
        }
        .parameterMotion(.none)
        .node
    }

    /// A BODY'S SPRING IS THE ONE IT WAS GIVEN, whichever body it is, and the standard one where none is named.
    func testABodysSpringIsTheOneItWasGiven() {
        let spring = Spring(response: .milliseconds(420), damping: 0.55)

        XCTAssertEqual(LayoutBody.followsLayout(spring).spring, spring)
        XCTAssertEqual(LayoutBody.onChange(spring).spring, spring)
        XCTAssertEqual(LayoutBody.followsLayout(Spring(damping: .nan)).spring, .standard)
        XCTAssertEqual(LayoutBody.onChange().spring, .standard)
    }

    /// A VIEW'S BODY FOLLOWS THE STATE ITS VIEW READS: a switch the views' own closure reads turns their bodies on,
    /// the layout described again for that alone - nothing around it built.
    func testAViewsBodyFollowsTheStateItsViewReads() throws {
        try bodyFollowsTheStateItsViewReads(shaded: false)
        try bodyFollowsTheStateItsViewReads(shaded: true)
    }

    /// The same, the views held as a shaded layout holds them.
    private func bodyFollowsTheStateItsViewReads(shaded: Bool) throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
        let (phase, sways) = (State(wrappedValue: 0.0), State(wrappedValue: false))
        let renders = Renders()
        func built() -> Node {
            let layout = MotionLayout([0], parameters: phase.projectedValue) { index in
                if sways.wrappedValue {
                    Text("\(index)").layoutBody(.followsLayout(Spring(response: .milliseconds(400), damping: 0.5)))
                } else {
                    Text("\(index)")
                }
            } placements: { _, at in
                [Placement(Rect(at * 100, 0, 10, 10))]
            }
            .parameterMotion(.none)
            return (shaded ? layout.shade { Rectangle() } : layout).node
        }
        let layout = try XCTUnwrap(bench.laid(renders, built).patch.first(.motionLayout))
        let worn = try XCTUnwrap(layout.driven?[.parameters]?.state)
        // Read off the answer as the host does, no tree described again: a new description would read the bodies
        // anew.
        func body() -> LayoutBody? { bench.answer.views.first?.body }
        moved(worn, to: [1, 1, 0], mask: 0b111)
        bench.cycle()
        XCTAssertNil(body(), "no body of its own yet (shaded \(shaded))")

        sways.wrappedValue = true
        renders.revisit(changed: Renderer.shared.pendingChanges)
        moved(worn, to: [2, 2, 0], mask: 0b111)
        bench.cycle()
        XCTAssertEqual(
            body(), .followsLayout(Spring(response: .milliseconds(400), damping: 0.5)),
            "a body now: answered as following its place (shaded \(shaded))")
    }

    /// A VIEW FOLLOWING ITS PLACE IS ANSWERED SO, ON ITS OWN SPRING; the layout's own views are answered none of
    /// their own.
    func testAFollowingViewIsAnsweredAmongTheLayoutsOwn() throws {
        let phase = State(wrappedValue: 0.0)
        _ = bench.laid(Renders(), { self.tree(phase) })

        XCTAssertEqual(bench.answer.views.map(\.body), [
            .followsLayout(Spring(response: .milliseconds(400), damping: 0.5)), nil,
        ])
    }
}
