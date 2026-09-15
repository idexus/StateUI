// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// SHOWING AND HIDING CROSSES: a view being hidden fades to nothing first and
/// goes when it gets there, and one being shown comes up from nothing, so two
/// views in one slot change over rather than blink.
final class AppKitVisibilityTests: XCTestCase {
    /// A label, visible or not, crossing under `motion`.
    private func label(visible: Bool, motion: Motion = .eased(100, .linear)) -> HostPatch {
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties[.text] = .string("here")
        label.properties[.isVisible] = .bool(visible)
        label.motion = HostLayoutMotion(motion: motion, lanes: .all)
        return label
    }

    @MainActor
    private func renderer(_ now: @escaping () -> Double) -> AppKitRenderer {
        AppKitRenderer(resourceDirectory: nil, presentsWindows: false, clock: now, reducesMotion: { false })
    }

    /// A view hidden fades to nothing, deaf to input on its way, and is hidden
    /// only once the fade lands - left at the opacity the tree describes, so
    /// its next showing starts from somewhere honest.
    @MainActor
    func testHidingAViewFadesItAndOnlyThenHidesIt() throws {
        var now = 0.0
        let renderer = renderer { now }
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(label(visible: true))
        let view = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")) as? AppKitHitTestView)

        renderer.applyForTesting(label(visible: false))
        XCTAssertFalse(view.isHidden, "still there, on its way out")
        XCTAssertTrue(view.inputTransparencyForTesting.transparent, "and answering no input while it goes")

        now = 50
        renderer.stepTripsForTesting()
        XCTAssertEqual(view.alphaValue, 0.5, accuracy: 0.001)
        XCTAssertFalse(view.isHidden)

        now = 100
        renderer.stepTripsForTesting()
        XCTAssertTrue(view.isHidden, "hidden when the fade landed")
        XCTAssertEqual(view.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(view.inputTransparencyForTesting.transparent)
    }

    /// A view described hidden is simply hidden; shown, it comes up from
    /// nothing.
    @MainActor
    func testShowingAViewBringsItUpFromNothing() throws {
        var now = 0.0
        let renderer = renderer { now }
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(label(visible: false))
        let view = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        XCTAssertTrue(view.isHidden, "a first description has nothing to cross from")

        renderer.applyForTesting(label(visible: true))
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.alphaValue, 0, accuracy: 0.001)

        now = 100
        renderer.stepTripsForTesting()
        XCTAssertEqual(view.alphaValue, 1, accuracy: 0.001)
    }

    /// A view that faded away and is shown again under `.motion(.none)` is
    /// back at once and answers input: the fade's deafness never outlives it.
    @MainActor
    func testAViewShownAgainWithoutTravellingAnswersInput() throws {
        var now = 0.0
        let renderer = renderer { now }
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(label(visible: true))
        let view = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")) as? AppKitHitTestView)

        renderer.applyForTesting(label(visible: false))
        now = 100
        renderer.stepTripsForTesting()
        renderer.applyForTesting(label(visible: true, motion: Motion.none))

        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(view.inputTransparencyForTesting.transparent)
    }

    /// A row that fades out of a stack is closed over once it has gone: the
    /// rows under it travel up into its place - the end of the change the
    /// patch began.
    @MainActor
    func testAStackClosesOverARowOnceItsFadeLands() throws {
        var now = 0.0
        let renderer = renderer { now }
        defer { renderer.closeForTesting() }

        func rows(firstVisible: Bool) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
            var first = HostPatch(id: .manual("first"), type: .colorBox)
            first.properties = [
                .width: .number(100), .height: .number(40), .isVisible: .bool(firstVisible),
            ]
            first.motion = HostLayoutMotion(motion: .eased(100, .linear), lanes: .all)
            var second = HostPatch(id: .manual("second"), type: .colorBox)
            second.properties = [.width: .number(100), .height: .number(40)]
            stack.children = .arranged([first, second])
            return stack
        }

        renderer.applyForTesting(rows(firstVisible: true))
        let stack = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let second = try XCTUnwrap(renderer.viewForTesting(id: .manual("second")))
        stack.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        stack.layoutSubtreeIfNeeded()
        XCTAssertEqual(second.frame.minY, 40, accuracy: 0.001)

        renderer.applyForTesting(rows(firstVisible: false))
        stack.layoutSubtreeIfNeeded()
        XCTAssertEqual(second.frame.minY, 40, accuracy: 0.001, "the row fades where it stands")

        now = 100
        renderer.stepTripsForTesting()
        stack.layoutSubtreeIfNeeded()
        XCTAssertEqual(second.frame.minY, 40, accuracy: 0.001, "the row below starts once it has gone")

        now = 200
        renderer.stepTripsForTesting()
        stack.layoutSubtreeIfNeeded()
        XCTAssertEqual(second.frame.minY, 20, accuracy: 0.001, "and travels into its place")

        now = 300
        renderer.stepTripsForTesting()
        stack.layoutSubtreeIfNeeded()
        XCTAssertEqual(second.frame.minY, 0, accuracy: 0.001)
    }

    /// Shown again while it fades, a view comes back up from where it stands,
    /// is never hidden, and answers input again.
    @MainActor
    func testAViewShownAgainMidFadeComesBackFromWhereItStands() throws {
        var now = 0.0
        let renderer = renderer { now }
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(label(visible: true))
        let view = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")) as? AppKitHitTestView)

        renderer.applyForTesting(label(visible: false))
        now = 50
        renderer.stepTripsForTesting()
        renderer.applyForTesting(label(visible: true))
        XCTAssertEqual(view.alphaValue, 0.5, accuracy: 0.001, "from where it stands")
        XCTAssertFalse(view.inputTransparencyForTesting.transparent)

        now = 150
        renderer.stepTripsForTesting()
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.alphaValue, 1, accuracy: 0.001)
    }
}
#endif
