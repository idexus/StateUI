// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An aim is an id nobody spells: the differ fills it with the element's own
// identity, and the act aims with the number. These tests drive the differ for
// real - a fresh Differ counts identities from 1, so every number here is
// exact rather than matched by shape.

import XCTest
@_spi(Host) @testable import StateUI

final class AimTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    // MARK: - The lifecycle

    /// The whole mechanism in one test: `.aim(_:)` links the box, the walk
    /// writes the identity the element settled on, and the identity being
    /// stable is what keeps the aim stable across renders.
    func testAnAimTakesTheIdentityTheDifferSettled() throws {
        let renders = Renders()
        let panel = Aim(Border.self)

        renders.render(stack([Border().aim(panel).body], id: "root"))

        XCTAssertEqual(try panel.box.target, .number(1))
        XCTAssertEqual(panel.description, "#1")

        renders.render(stack([Border().aim(panel).opacity(0.5).body], id: "root"))

        XCTAssertEqual(
            try panel.box.target, .number(1),
            "the element's identity is stable, so the aim is")
    }

    /// A resync describes everything and matches everything - the aim is
    /// restamped with the identity it already had.
    func testAResyncKeepsTheAim() throws {
        let renders = Renders()
        let panel = Aim(Border.self)
        let tree = stack([Border().aim(panel).body], id: "root")

        renders.render(tree)
        renders.renderFromScratch(tree)

        XCTAssertEqual(try panel.box.target, .number(1))
    }

    /// Leaving the tree ends the element, and a view that returns is a NEW
    /// one - the aim follows to the new element's identity, exactly as an
    /// ordinary `@State` starts over.
    func testAnAimFollowsTheViewThatLeavesAndReturns() throws {
        let renders = Renders()
        let panel = Aim(Border.self)

        func tree(showing: Bool) -> Node {
            stack(showing ? [Border().aim(panel).body] : [], id: "root")
        }

        renders.render(tree(showing: true))
        let first = try panel.box.target

        renders.render(tree(showing: false))
        renders.render(tree(showing: true))
        let second = try panel.box.target

        XCTAssertEqual(first, .number(1))
        XCTAssertEqual(second, .number(2), "the returned view is a new element")
    }

    /// An aim takes no part in MATCHING: a view carrying only one is
    /// identified by where it stands, so `.id()` beside it still owns the row
    /// identity - and the act then aims with the NAME, both being one element.
    func testAnAimBesideAnAuthorsIdAimsWithTheName() throws {
        let renders = Renders()
        let row = Aim(Border.self)

        renders.render(stack([Border().id("row-7").aim(row).body], id: "root"))

        XCTAssertEqual(try row.box.target, .string("row-7"))
    }

    // MARK: - What throws, and why

    /// Before `.aim(_:)` has rendered there is nothing to aim at, and an act
    /// that goes nowhere looks exactly like one that has not started - so it
    /// throws instead.
    func testAnAimOnNoViewThrows() {
        let panel = Aim(Border.self)

        XCTAssertThrowsError(try panel.box.target) { error in
            XCTAssertTrue("\(error)".contains("on no view"), "\(error)")
        }
        XCTAssertEqual(panel.description, "nowhere")
    }

    /// The same, through the public act itself: the throw happens HERE, before
    /// anything is queued, so nothing reaches the host at all.
    func testAnAimOnNoViewThrowsFromTheActItself() async {
        let panel = Aim(Border.self)
        _ = Renderer.shared.takeCommandsWire()

        do {
            try await panel.focus()
            XCTFail("an aim on no view must throw")
        } catch {
            XCTAssertTrue("\(error)".contains("on no view"), "\(error)")
        }

        XCTAssertFalse(
            drainedActs().contains { $0.name == "focus" },
            "nothing may be queued for an act that could not say its view")
    }

    /// One of these names ONE view. Put on two in the same render, the act
    /// reports the conflict - and fixing the tree fixes the aim, because the
    /// next walk's first attachment starts it over.
    func testOneAimOnTwoViewsIsAConflictTheActReports() throws {
        let renders = Renders()
        let panel = Aim(Border.self)

        renders.render(stack([
            Border().aim(panel).body,
            Border().aim(panel).body,
        ], id: "root"))

        XCTAssertThrowsError(try panel.box.target) { error in
            XCTAssertTrue("\(error)".contains("two views"), "\(error)")
        }
        XCTAssertEqual(panel.description, "two views")

        renders.render(stack([Border().aim(panel).body], id: "root"))

        XCTAssertEqual(
            try panel.box.target, .number(1),
            "one view again, and the surviving element's identity answers")
    }

    // MARK: - Composed views

    /// Two instances of one composed view are two elements, so each instance's
    /// aim points at its own - the point of it being PER INSTANCE where a name
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

    /// An aim on the composed view at the call site and one on its content's
    /// root name the SAME element - which a string id inside the content never
    /// could, the identity being fixed on the placeholder before the content
    /// exists. See Core/Aim.swift's header.
    func testAnAimOnTheComposedViewAndInsideItAgree() throws {
        let renders = Renders()
        let outer = Aim(Carded.self)
        let card = Carded()

        renders.render(stack([card.aim(outer).body], id: "root"))

        XCTAssertEqual(try outer.box.target, try card.inner.box.target)
    }

    /// A carried view is not walked - and the box simply keeps the identity
    /// it has, which is still the element's. A view built again restamps it
    /// with the same one.
    func testAnAimUnderACarriedViewKeepsItsTarget() throws {
        struct Framed: ContentView {
            let panel: Aim<Border>
            let tag: Int
            var content: any View { Border().aim(panel) }
        }

        let renders = Renders()
        let panel = Aim(Border.self)

        func tree(_ tag: Int) -> Node {
            stack([Framed(panel: panel, tag: tag).body], id: "root")
        }

        renders.render(tree(1))
        let first = try panel.box.target
        renders.render(tree(1))
        XCTAssertEqual(try panel.box.target, first, "a carried view leaves the aim standing")
        renders.render(tree(2))
        XCTAssertEqual(try panel.box.target, first, "a rebuilt one restamps the same identity")
    }

    // MARK: - Declared, handed, and held by a model

    /// A view is built again with a fresh `@Aim` on every render, and the fresh
    /// one takes over its predecessor's box - so a handler captured at the
    /// first build aims where the latest build put the aim.
    func testADeclaredAimKeepsOneBoxAcrossBuilds() throws {
        let renders = Renders()
        let first = Panelled()
        renders.render(stack([first.body], id: "root"))

        let second = Panelled()
        renders.render(stack([second.body], id: "root"))

        XCTAssertTrue(
            second.panel.box === first.panel.box,
            "the fresh aim took over its predecessor's box")
        XCTAssertEqual(try first.panel.target, try second.panel.target)
    }

    /// A view HANDED its parent's aim is carried when the parent builds again
    /// with nothing else changed: the parent's fresh aim took over its
    /// predecessor's box, and the child compares what it was handed by that
    /// box - not by the aim object, which is new on every build.
    func testAViewHandedAnAimIsCarriedWhenItsParentBuildsAgain() throws {
        let renders = Renders()
        let tag = State(wrappedValue: 0)
        let builds = Builds()

        renders.render(stack([Handing(tag: tag.projectedValue, builds: builds).body], id: "root"))
        XCTAssertEqual(builds.count, 1)

        tag.wrappedValue = 1
        renders.render(
            stack([Handing(tag: tag.projectedValue, builds: builds).body], id: "root"),
            changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 1, "the child was handed the same aim, and nothing else it holds moved")
    }

    /// A view handed ONE of its parent's two aims, then the other, aims
    /// through what it is handed - and neither of the parent's aims is taken
    /// over: adopting what a view was handed would give the second aim the
    /// first one's box, and both would reach one control.
    func testAViewHandedAnotherAimTakesOverNeitherOfItsParents() throws {
        let renders = Renders()
        let picksRight = State(wrappedValue: false)
        let builds = Builds()

        renders.render(stack(
            [Choosing(picksRight: picksRight.projectedValue, builds: builds).body], id: "root"))

        picksRight.wrappedValue = true
        let second = Choosing(picksRight: picksRight.projectedValue, builds: builds)
        renders.render(stack([second.body], id: "root"), changed: Renderer.shared.pendingChanges)

        XCTAssertNotEqual(
            try second.left.target, try second.right.target,
            "each of the parent's aims still reaches a control of its own")
    }

    /// A model declares its aim the way a view does, and the aim reaches the
    /// field it is put on - the walk never enters the model, which the view's
    /// `@State` keeps.
    func testAModelsAimReachesTheFieldItIsPutOn() throws {
        let renders = Renders()
        let page = FormPage()

        renders.render(stack([page.body], id: "root"))

        XCTAssertEqual(try page.form.field.target, .number(1))
    }

    // MARK: - What an APPLICATION can write

    /// An application's own act aims at a control the same way the library's
    /// own acts do, and `spin()` below is the proof: it is written entirely in
    /// public API, in this package, the way an application would write it.
    ///
    /// `Aim.target` is public because an application that can register a
    /// control (`StateUIControls.Add`) and register an act (`StateUIActs.Add`)
    /// must be able to AIM one at the other - with the target internal, that
    /// last door stays closed in a surface whose whole promise is that an
    /// application writes what the library writes.
    func testAnApplicationsOwnActAimsWithTheSamePublicTarget() async throws {
        let renders = Renders()
        let wheel = Aim(Border.self)

        renders.render(stack([Border().aim(wheel).body], id: "root"))
        _ = Renderer.shared.takeCommandsWire()

        async let spun: Void = wheel.spin(by: 90)

        // The act is queued with the element's identity in front of its own
        // arguments, which is the order every act of the library's uses.
        try await Task.sleep(nanoseconds: 20_000_000)
        let queued = drainedActs()

        XCTAssertEqual(queued.first?.name, "Gallery.Spin")
        XCTAssertEqual(queued.first?.arguments.first, .number(1), "the element it was put on")
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
extension Aim {
    fileprivate func spin(by degrees: Double) async throws {
        try await stateUICall(.spin, [try target, .number(degrees)])
    }
}

/// A composed view holding a control of its own - what the per-instance tests
/// render two of. Declared with `@Aim`, the way an application declares one.
private struct Panelled: ContentView {
    @Aim(Border.self) var panel

    var content: any View {
        Border().aim(panel)
    }
}

/// A composed view whose content's ROOT is aimed at, for the test that pins
/// the inside and the outside naming one element.
private struct Carded: ContentView {
    @Aim(Border.self) var inner

    var content: any View {
        Border().aim(inner)
    }
}

/// How many times a body ran - an object, so a view holding it compares it by
/// identity and is carried where nothing else it holds moved.
private final class Builds {
    var count = 0
}

/// A view HANDED an aim, putting it on a border of its own.
private struct Handed: ContentView {
    let panel: Aim<Border>
    let builds: Builds

    var content: any View {
        builds.count += 1
        return Border().aim(panel)
    }
}

/// A view that declares an aim and hands it to a child - and reads a state in
/// its own body, so a write to it builds this view again.
private struct Handing: ContentView {
    @Aim(Border.self) var panel
    @Binding var tag: Int
    let builds: Builds

    var content: any View {
        let shown = "\(tag)"

        return VStack {
            Label(shown)
            Handed(panel: panel, builds: builds)
        }
    }
}

/// A view that declares two aims and hands a child one or the other, putting
/// the one it did not hand on a border of its own.
private struct Choosing: ContentView {
    @Aim(Border.self) var left
    @Aim(Border.self) var right
    @Binding var picksRight: Bool
    let builds: Builds

    var content: any View {
        let handsRight = picksRight

        return VStack {
            Handed(panel: handsRight ? right : left, builds: builds)
            Border().aim(handsRight ? left : right)
        }
    }
}

/// A model holding the aim at the field it shows - the shape a page with a
/// form has, where the handler that focuses a field lives beside the state
/// that field shows.
private final class Form {
    @State var note = ""

    @Aim(Entry.self) var field
}

/// A view keeping such a model.
private struct FormPage: ContentView {
    @State var form = Form()

    var content: any View {
        Entry(form.$note).aim(form.field)
    }
}
