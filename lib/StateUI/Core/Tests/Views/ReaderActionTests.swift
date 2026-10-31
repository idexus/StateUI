// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// What a screen reader does to a view: an action by its words, a step up or down.
@MainActor
final class ReaderActionTests: XCTestCase {
    /// What a view's handlers heard.
    private final class Heard {
        var said: [String] = []
    }

    /// A view offers its actions in the order written, and each name reaches its own handler alone.
    func testEachActionReachesItsOwnHandler() throws {
        let heard = Heard()
        let renders = Renders()
        let patch = renders.render(
            HStack {}
                .accessibilityAction("Archive") { heard.said.append("archived") }
                .accessibilityAction("Delete") { heard.said.append("deleted") }
                .node)
        let performed = try XCTUnwrap(patch.events?["accessibilityActionPerformed"])

        XCTAssertEqual(patch.props["accessibilityActions"], ["Archive", "Delete"].propValue)
        renders.fire(performed, with: [.string("Delete")])
        renders.fire(performed, with: [.string("Share")])
        renders.fire(performed, with: [.string("Archive")])

        XCTAssertEqual(heard.said, ["deleted", "archived"])
    }

    /// A step up or down reaches the view's handler as the way it went.
    func testAStepReachesTheViewAsItsWay() throws {
        var steps: [AccessibilityAdjustment] = []
        let renders = Renders()
        let patch = renders.render(HStack {}.accessibilityRole(.adjustable).onAccessibilityAdjusted { steps.append($0) }.node)
        let stepped = try XCTUnwrap(patch.events?["accessibilityAdjusted"])

        renders.fire(stepped, with: [AccessibilityAdjustment.increment.propValue])
        renders.fire(stepped, with: [AccessibilityAdjustment.decrement.propValue])

        XCTAssertEqual(steps, [.increment, .decrement])
    }
}
