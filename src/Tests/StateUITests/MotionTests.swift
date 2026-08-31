// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A VALUE THAT CHANGES TRAVELS. What these pin is the Swift half of that: which
// property changes get a motion written beside them, which get none, and what
// the numbers in one are.
//
// The rule is one sentence - every property of a CONTINUING element whose value
// has a half-way - and everything below is one of the ways out of it: an element
// being described for the first time, a value with no half-way, a place or a
// count, a property the library computes, a write the author snapped, and a
// flight, which wins because someone is waiting for it.
//
// The host's half is FlightTests.cs and MotionTests.cs.

import XCTest
@testable import StateUI

final class MotionTests: XCTestCase {
    /// A border of a stated opacity, which is a number with a half-way.
    private func panel(_ opacity: Double, id: String = "panel") -> Node {
        Border { Label("x") }.opacity(opacity).id(id).body
    }

    // ---- What travels -------------------------------------------------------

    func testAChangedNumberTravelsAtTheApplicationsMotion() {
        let renders = Renders()

        renders.render(panel(1))
        let patch = renders.render(panel(0.25))

        let motion = patch.transitions[.opacity]
        XCTAssertEqual(patch.props[.opacity], .number(0.25), "the target rides as itself")
        XCTAssertEqual(motion?.motion, .standard)
        XCTAssertEqual(motion?.channel, 0, "nobody started it and nobody waits for it")
        XCTAssertEqual(motion?.report, 0)
    }

    func testTheApplicationSaysHowEverythingTravels() {
        let renders = Renders()
        let own = Motion.spring(response: 260, damping: 0.8)

        renders.render(panel(1), motion: own)
        let patch = renders.render(panel(0.25), motion: own)

        XCTAssertEqual(patch.transitions[.opacity]?.motion, own)
    }

    func testAColourTravels() {
        let renders = Renders()

        renders.render(Border { Label("x") }.backgroundColor(Color("#000000")).id("b").body)
        let patch = renders.render(
            Border { Label("x") }.backgroundColor(Color("#FFFFFF")).id("b").body)

        XCTAssertNotNil(patch.transitions[.backgroundColor])
    }

    func testEdgesTravel() {
        let renders = Renders()

        renders.render(VStack { Label("x") }.padding(Thickness(4)).id("s").body)
        let patch = renders.render(VStack { Label("x") }.padding(Thickness(16)).id("s").body)

        XCTAssertNotNil(patch.transitions[.padding])
    }

    // ---- What arrives instead ----------------------------------------------

    /// The first thing anyone sees is always the thing itself. An element being
    /// described for the first time has no "before" to travel from, so first
    /// render at target is a fact of the bytes rather than a rule the host has
    /// to work out.
    func testAFirstDescriptionCarriesNoMotion() {
        let renders = Renders()

        let patch = renders.render(panel(0.25))

        XCTAssertEqual(patch.props[.opacity], .number(0.25))
        XCTAssertTrue(patch.transitions.isEmpty)
    }

    /// A resync describes the whole tree to a host that may be holding nothing.
    /// There is no "before" on that side either.
    func testAResyncCarriesNoMotion() {
        let renders = Renders()

        renders.render(panel(1))
        let patch = renders.renderFromScratch(panel(0.25))

        XCTAssertEqual(patch.props[.opacity], .number(0.25))
        XCTAssertTrue(patch.transitions.isEmpty)
    }

    /// A control being built again cannot travel from what the last one showed.
    func testAReplacedElementCarriesNoMotion() {
        let renders = Renders()

        renders.render(panel(1))
        let patch = renders.render(Label("x").opacity(0.25).id("panel").body)

        XCTAssertTrue(patch.replace)
        XCTAssertTrue(patch.transitions.isEmpty)
    }

    func testAViewToldToStayStillDoesNot() {
        let renders = Renders()

        renders.render(Border { Label("x") }.opacity(1).motion(.none).id("p").body)
        let patch = renders.render(Border { Label("x") }.opacity(0.25).motion(.none).id("p").body)

        XCTAssertEqual(patch.props[.opacity], .number(0.25))
        XCTAssertTrue(patch.transitions.isEmpty)
    }

    /// One element's motion is that element's. Nothing in this library reaches
    /// down a tree.
    func testAMotionIsNotInherited() {
        let renders = Renders()

        func tree(_ opacity: Double) -> Node {
            VStack {
                Border { Label("x") }.opacity(opacity).id("inner")
            }
            .motion(.none)
            .id("outer")
            .body
        }

        renders.render(tree(1))
        let patch = renders.render(tree(0.25))

        XCTAssertNotNil(
            patch.child("inner")?.transitions[.opacity],
            "the child travels at the application's motion, not its parent's")
    }

    /// A modifier written ON a composed view is about that view, and a
    /// modifier that compiles, renders nothing and says nothing is the one
    /// failure this library refuses to ship.
    func testAMotionWrittenOnAComposedViewReachesWhatItIsMadeOf() {
        struct Panel: ContentView {
            let fade: Double

            var content: Element {
                Border { Label("x") }.opacity(fade)
            }
        }

        let renders = Renders()

        renders.render(Panel(fade: 1).motion(.none).id("p").body)
        let patch = renders.render(Panel(fade: 0.25).motion(.none).id("p").body)

        XCTAssertEqual(patch.props[.opacity], .number(0.25))
        XCTAssertTrue(patch.transitions.isEmpty, "the view was told to stay still")
    }

    /// There is no half of a word.
    func testAValueWithNoHalfWayArrives() {
        let renders = Renders()

        renders.render(Label("one").id("l").body)
        let patch = renders.render(Label("two").id("l").body)

        XCTAssertEqual(patch.props[.text], .string("two"))
        XCTAssertTrue(patch.transitions.isEmpty)
    }

    /// Nothing walks a whole number: which tab, which item, which row.
    func testAPlaceOrACountNeverTravels() {
        let renders = Renders()

        renders.render(Label("x").gridRow(0).id("l").body)
        let patch = renders.render(Label("x").gridRow(3).id("l").body)

        XCTAssertEqual(patch.props[.gridRow], .number(3))
        XCTAssertTrue(patch.transitions.isEmpty)

        for property in Prop.unmoved {
            XCTAssertFalse(
                property.name.isEmpty,
                "a property that never travels still has to be a property")
        }
    }

    /// WHERE A CHILD SITS IS THE HOST'S, not a property's: a placement arrives
    /// and the LAYOUT carries the child from one place to the next. The values
    /// the author wrote on the same view travel as usual.
    func testAPlacementArrivesWhileTheRestOfTheViewTravels() {
        let renders = Renders()

        func row(_ y: Double, _ opacity: Double) -> Node {
            Border { Label("x") }
                .absoluteLayoutBounds(Rect(0, y, 1, 40))
                .opacity(opacity)
                .id("row")
                .body
        }

        renders.render(row(0, 1))
        let patch = renders.render(row(80, 0.5))

        XCTAssertNil(patch.transitions[.absoluteLayoutBounds], "the placement arrives")
        XCTAssertNotNil(patch.transitions[.opacity], "what the author wrote travels")
    }

    /// A layout says how its children travel, and one that says nothing
    /// travels the way the application does - which is not on the wire at all.
    func testALayoutSaysHowItsChildrenTravelOnlyWhenItDiffers() {
        let renders = Renders()

        let plain = renders.render(VStack { Label("x") }.id("s").body)
        XCTAssertNil(plain.motion, "a layout that agrees says nothing")

        let told = renders.render(
            VStack { Label("x") }.motion(.none).id("s").body)

        XCTAssertEqual(told.motion, Motion.none)

        let back = renders.render(VStack { Label("x") }.id("s").body)

        XCTAssertEqual(
            back.motion, Motion.inherited,
            "and a layout that STOPS saying so has to be heard saying it")
    }

    /// A view that places nothing and has no states says nothing: there is
    /// nothing the host has to work out for itself.
    func testAViewThatMovesNothingItselfSaysNothing() {
        let renders = Renders()

        let patch = renders.render(Label("x").motion(.none).id("l").body)

        XCTAssertNil(patch.motion)
    }

    /// A VISUAL STATE is applied by the platform, outside every message, so a
    /// control that has one has to say how the values it changes travel.
    func testAControlWithVisualStatesSaysHowItMoves() {
        let renders = Renders()

        func button(_ still: Bool) -> Node {
            let base = Button("Save")
                .visualState(.disabled) { $0.backgroundColor(Color("#CCCCCC")) }

            return (still ? base.motion(.none) : base).id("b").body
        }

        XCTAssertNil(
            renders.render(button(false)).motion,
            "a control that travels the way the application does says nothing")

        XCTAssertEqual(
            renders.render(button(true)).motion, Motion.none,
            "and one that does not, says so")
    }

    // ---- A write of its own -------------------------------------------------

    /// `snap(to:)` is one WRITE and not a setting: the next assignment to the
    /// same state travels again.
    func testASnappedWriteArrivesAndTheNextOneTravels() {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()

        func panel() -> Node {
            Border { Label("x") }.opacity(fade.projectedValue).id("p").body
        }

        renders.render(panel())

        fade.projectedValue.snap(to: 0.5)
        let snapped = renders.render(panel())

        XCTAssertEqual(snapped.props[.opacity], .number(0.5))
        XCTAssertTrue(snapped.transitions.isEmpty, "this write lands at once")

        fade.wrappedValue = 0.25
        let travelled = renders.render(panel())

        XCTAssertNotNil(travelled.transitions[.opacity], "and the next one travels")
    }

    /// A flight is someone waiting, so it wins - and its channel says so.
    func testAFlightWinsOverTheOrdinaryMotion() {
        let fade = State(wrappedValue: 1.0)
        let key = FlightKey(lender: ObjectIdentifier(fade.projectedValue.lender!), lent: nil)
        let renders = Renders()

        func panel() -> Node {
            Border { Label("x") }.opacity(fade.projectedValue).id("p").body
        }

        renders.render(panel())

        fade.wrappedValue = 0.25
        let patch = renders.render(panel(), flights: [
            key: PendingFlight(
                motion: .eased(400, .cubicIn),
                channel: -1,
                report: 0,
                lender: fade.projectedValue.lender!),
        ])

        let transition = patch.transitions[.opacity]

        XCTAssertEqual(transition?.channel, -1, "someone is waiting for this one")
        XCTAssertEqual(transition?.motion, .eased(400, .cubicIn))
    }

    /// A flight that says nothing about how to travel travels the way the
    /// element does - which is what makes `animateTo(x)` and `x = …` agree
    /// about the motion and differ only in being awaited.
    func testAFlightWithNoMotionOfItsOwnTravelsLikeTheElement() {
        let fade = State(wrappedValue: 1.0)
        let key = FlightKey(lender: ObjectIdentifier(fade.projectedValue.lender!), lent: nil)
        let renders = Renders()
        let own = Motion.eased(700, .sinInOut)

        func panel() -> Node {
            Border { Label("x") }.opacity(fade.projectedValue).id("p").body
        }

        renders.render(panel(), motion: own)

        fade.wrappedValue = 0.25
        let patch = renders.render(panel(), motion: own, flights: [
            key: PendingFlight(
                motion: .inherited,
                channel: -1,
                report: 0,
                lender: fade.projectedValue.lender!),
        ])

        XCTAssertEqual(patch.transitions[.opacity]?.motion, own)
    }

    // ---- A layout of the author's own ---------------------------------------

    /// One closure is the whole layout: it is handed which view this is, how
    /// many there are and the room, and what it answers is where that view
    /// goes.
    func testAPlacedLayoutPutsEachViewWhereItsArithmeticSays() {
        let renders = Renders()

        func tree() -> Node {
            Placed([1, 2, 3], id: \.self, at: { index, count, room in
                Rect(room.width / Double(count) * Double(index), 0, 40, 40)
            }) { number in
                Label("\(number)")
            }
            .id("fan")
            .body
        }

        var patch = renders.render(tree())

        // The room has to be measured before anything can be put in it, so the
        // first showing is one frame late and every view sits at nothing.
        func reader(_ patch: Patch) -> Int? {
            if let id = patch.events?[.frameChanged] { return id }

            for child in patch.children {
                if let id = reader(child) { return id }
            }

            return nil
        }

        XCTAssertTrue(renders.fire(
            reader(patch) ?? -1, with: [.numbers([0, 0, 300, 100, 0, 0, 0, 0])]))

        patch = renders.renderFromScratch(tree())

        func layout(_ patch: Patch) -> Patch? {
            if patch.type == .absoluteLayout { return patch }

            for child in patch.children {
                if let found = layout(child) { return found }
            }

            return nil
        }

        let placed = layout(patch)?.children ?? []

        XCTAssertEqual(placed.count, 3)
        XCTAssertEqual(placed[0].props[.absoluteLayoutBounds], .numbers([0, 0, 40, 40]))
        XCTAssertEqual(placed[1].props[.absoluteLayoutBounds], .numbers([100, 0, 40, 40]))
        XCTAssertEqual(placed[2].props[.absoluteLayoutBounds], .numbers([200, 0, 40, 40]))
    }

    /// A layout of your own moves like every other one, and is held still the
    /// same way - which a placement worked out from something the reader is
    /// dragging wants.
    func testAPlacedLayoutSaysHowItsViewsTravel() {
        let renders = Renders()

        func tree(_ still: Bool) -> Node {
            let fan = Placed([1], id: \.self, at: { _, _, _ in Rect(0, 0, 40, 40) }) { number in
                Label("\(number)")
            }

            return (still ? fan.motion(.none) : fan).id("fan").body
        }

        func layout(_ patch: Patch) -> Patch? {
            if patch.type == .absoluteLayout { return patch }

            for child in patch.children {
                if let found = layout(child) { return found }
            }

            return nil
        }

        XCTAssertEqual(layout(renders.render(tree(true)))?.motion, Motion.none)
    }

    // ---- The vocabulary itself ---------------------------------------------

    func testTheLawsCarryTheNumbersTheyNeed() {
        XCTAssertEqual(Motion.eased(400, .cubicIn).millis, 400)
        XCTAssertEqual(Motion.eased(400, .cubicIn).curve, .cubicIn)

        XCTAssertEqual(Motion.spring(response: 260, damping: 0.7).millis, 260)
        XCTAssertEqual(Motion.spring(response: 260, damping: 0.7).factor, 0.7)

        XCTAssertEqual(Motion.decay(friction: 0.006).factor, 0.006)
    }

    func testNoMotionIsNothingAndInheritedResolves() {
        XCTAssertTrue(Motion.none.isNothing)
        XCTAssertFalse(Motion.standard.isNothing)

        XCTAssertEqual(Motion.inherited.resolved(against: .standard), .standard)
        XCTAssertEqual(Motion.eased(50).resolved(against: .standard), .eased(50))
    }

    /// A spring's damping is bought deliberately and never given away: half a
    /// card's worth of wobble is what a reader reads as a mistake.
    func testASpringDoesNotOvershootUnlessItIsAskedTo() {
        XCTAssertEqual(Motion.spring().factor, 1)
    }
}
