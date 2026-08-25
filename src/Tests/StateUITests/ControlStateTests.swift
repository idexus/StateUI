// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control in state is an id nobody spells: the differ fills it with the
// element's own identity, and the act aims with the number. These tests drive
// the differ for real - a fresh Differ counts identities from 1, so every
// number here is exact rather than matched by shape.

import XCTest
@testable import StateUI

final class ControlStateTests: XCTestCase {
    // MARK: - The lifecycle

    /// The whole mechanism in one test: `.assign()` links the box, the walk
    /// writes the identity the element settled on, and the identity being
    /// stable is what keeps the aim stable across renders.
    func testAnAssignedControlTakesTheIdentityTheDifferSettled() throws {
        let renders = Renders()
        let panel = ControlState<Border>()

        renders.render(stack([Border().assign(panel).body], id: "root"))

        XCTAssertEqual(try panel.box.target, .number(1))
        XCTAssertEqual(panel.description, "#1")

        renders.render(stack([Border().assign(panel).opacity(0.5).body], id: "root"))

        XCTAssertEqual(
            try panel.box.target, .number(1),
            "the element's identity is stable, so the aim is")
    }

    /// A resync describes everything and matches everything - the state is
    /// restamped with the identity it already had.
    func testAResyncKeepsTheAim() throws {
        let renders = Renders()
        let panel = ControlState<Border>()
        let tree = stack([Border().assign(panel).body], id: "root")

        renders.render(tree)
        renders.renderFromScratch(tree)

        XCTAssertEqual(try panel.box.target, .number(1))
    }

    /// Leaving the tree ends the element, and a view that returns is a NEW
    /// one - the state follows to the new element's identity, exactly as an
    /// ordinary `@State` starts over.
    func testAnAssignedControlFollowsTheViewThatLeavesAndReturns() throws {
        let renders = Renders()
        let panel = ControlState<Border>()

        func tree(showing: Bool) -> Node {
            stack(showing ? [Border().assign(panel).body] : [], id: "root")
        }

        renders.render(tree(showing: true))
        let first = try panel.box.target

        renders.render(tree(showing: false))
        renders.render(tree(showing: true))
        let second = try panel.box.target

        XCTAssertEqual(first, .number(1))
        XCTAssertEqual(second, .number(2), "the returned view is a new element")
    }

    /// An assignment takes no part in MATCHING: a view carrying only one is
    /// identified by where it stands, so `.id()` beside it still owns the row
    /// identity - and the act then aims with the NAME, both being one element.
    func testAnAssignmentBesideAnAuthorsIdAimsWithTheName() throws {
        let renders = Renders()
        let row = ControlState<Border>()

        renders.render(stack([Border().id("row-7").assign(row).body], id: "root"))

        XCTAssertEqual(try row.box.target, .string("row-7"))
    }

    // MARK: - What throws, and why

    /// Before `.assign()` has rendered there is nothing to aim at, and an act
    /// that goes nowhere looks exactly like one that has not started - so it
    /// throws instead.
    func testAnUnassignedControlStateThrows() {
        let panel = ControlState<Border>()

        XCTAssertThrowsError(try panel.box.target) { error in
            XCTAssertTrue("\(error)".contains("not assigned"), "\(error)")
        }
        XCTAssertEqual(panel.description, "unassigned")
    }

    /// The same, through the public act itself: the throw happens HERE, before
    /// anything is queued, so nothing reaches the host at all.
    func testAnUnassignedControlStateThrowsFromTheActItself() async {
        let panel = ControlState<Border>()
        _ = Renderer.shared.takeCommandsWire()

        do {
            try await panel.focus()
            XCTFail("a control state assigned to nothing must throw")
        } catch {
            XCTAssertTrue("\(error)".contains("not assigned"), "\(error)")
        }

        XCTAssertFalse(
            drainedActs().contains { $0.name == "focus" },
            "nothing may be queued for an act that could not say its view")
    }

    /// One of these names ONE view. Assigned to two in the same render, the act
    /// reports the conflict - and fixing the tree fixes the state, because the
    /// next walk's first assignment starts it over.
    func testOneControlStateOnTwoViewsIsAConflictTheActReports() throws {
        let renders = Renders()
        let panel = ControlState<Border>()

        renders.render(stack([
            Border().assign(panel).body,
            Border().assign(panel).body,
        ], id: "root"))

        XCTAssertThrowsError(try panel.box.target) { error in
            XCTAssertTrue("\(error)".contains("two views"), "\(error)")
        }
        XCTAssertEqual(panel.description, "conflicted")

        renders.render(stack([Border().assign(panel).body], id: "root"))

        XCTAssertEqual(
            try panel.box.target, .number(1),
            "one view again, and the surviving element's identity answers")
    }

    // MARK: - Composed views

    /// Two instances of one composed view are two elements, so each instance's
    /// state aims at its own - the point of it being PER INSTANCE where a name
    /// is global.
    func testTwoInstancesOfAComposedViewAimTheirOwnPanels() throws {
        let renders = Renders()
        let a = Panelled()
        let b = Panelled()

        renders.render(stack([a.body, b.body], id: "root"))

        let first = try a.panel.box.target
        let second = try b.panel.box.target

        XCTAssertEqual(first, .number(1))
        XCTAssertEqual(second, .number(2))
    }

    /// An assignment on the composed view at the call site and one on its
    /// content's root name the SAME element - which a string id inside the
    /// content never could, the identity being fixed on the placeholder before
    /// the content exists. See Core/ControlState.swift's header.
    func testAnAssignmentOnTheComposedViewAndInsideItAgree() throws {
        let renders = Renders()
        let outer = ControlState<Carded>()
        let card = Carded()

        renders.render(stack([card.assign(outer).body], id: "root"))

        XCTAssertEqual(try outer.box.target, try card.inner.box.target)
    }

    /// A memo that is not built is not walked - and the box simply keeps the
    /// identity it has, which is still the element's. A rebuilt memo restamps
    /// it with the same one.
    func testAnAssignedControlUnderAMemoKeepsItsAim() throws {
        let renders = Renders()
        let panel = ControlState<Border>()

        func tree(_ token: Int) -> Node {
            stack([Border().assign(panel).memoized(by: token).body], id: "root")
        }

        renders.render(tree(1))
        let first = try panel.box.target

        renders.render(tree(1))
        XCTAssertEqual(try panel.box.target, first, "an unbuilt memo leaves the aim standing")

        renders.render(tree(2))
        XCTAssertEqual(try panel.box.target, first, "a rebuilt one restamps the same identity")
    }

    // MARK: - What an APPLICATION can write

    /// An application's own act aims at a control the same way the library's
    /// own acts do, and `spin()` below is the proof: it is written entirely in
    /// public API, in this package, the way an application would write it.
    ///
    /// `ControlState.target` is public because an application that can
    /// register a control (`StateUIControls.Add`) and register an act
    /// (`StateUIActs.Add`) must be able to AIM one at the other - with the
    /// target internal, that last door stays closed in a surface whose whole
    /// promise is that an application writes what the library writes.
    func testAnApplicationsOwnActAimsWithTheSamePublicTarget() async throws {
        let renders = Renders()
        let wheel = ControlState<Border>()

        renders.render(stack([Border().assign(wheel).body], id: "root"))
        _ = Renderer.shared.takeCommandsWire()

        async let spun: Void = wheel.spin(by: 90)

        // The act is queued with the element's identity in front of its own
        // arguments, which is the order every act of the library's uses.
        try await Task.sleep(nanoseconds: 20_000_000)
        let queued = drainedActs()

        XCTAssertEqual(queued.first?.name, "Gallery.Spin")
        XCTAssertEqual(queued.first?.arguments.first, .number(1), "the element it was assigned to")
        XCTAssertEqual(queued.first?.arguments.last, .number(90))

        for id in queued.compactMap(\.completion) {
            ReplyBuffer.current = .finished([])
            _ = Renderer.shared.dispatch(id)
        }

        stateUIRunJobs()
        _ = try await spun
    }
}

/// An application's own vocabulary, declared the way Core/Tokens.swift declares
/// the library's - and namespaced, which is the advice `Act` gives.
extension Act {
    fileprivate static let spin = Act("Gallery.Spin")
}

/// And its own act, aimed with the public `target`. Nine lines, and every one
/// of them is something an application can write.
extension ControlState {
    fileprivate func spin(by degrees: Double) async throws {
        try await stateUICall(.spin, [try target, .number(degrees)])
    }
}

/// A composed view holding a control of its own - what the per-instance tests
/// render two of. Declared as `@State`, the way an application declares one.
private struct Panelled: ContentView {
    @State var panel = ControlState<Border>()

    var content: Element {
        Border().assign(panel)
    }
}

/// A composed view whose content's ROOT is assigned, for the test that pins the
/// inside and the outside naming one element.
private struct Carded: ContentView {
    @State var inner = ControlState<Border>()

    var content: Element {
        Border().assign(inner)
    }
}
