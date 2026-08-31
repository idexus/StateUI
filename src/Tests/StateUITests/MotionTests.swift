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

    /// A view that says nothing of its own says nothing on the wire: it
    /// travels the way the application does, and that is one number said once.
    func testAViewWithNoMotionOfItsOwnSaysNothing() {
        let renders = Renders()

        XCTAssertNil(renders.render(Label("x").id("l").body).motion)
    }

    /// A view that ANSWERS for itself says so, whatever it is - because what
    /// the host decides follows that answer: where it puts children, what a
    /// visual state changes, and whether showing and hiding crosses.
    func testAViewThatAnswersForItselfSaysSo() {
        let renders = Renders()

        XCTAssertEqual(
            renders.render(Label("x").motion(.none).id("l").body).motion, Motion.none)
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

    // ---- Which values a motion is about --------------------------------------

    /// A motion may name WHICH values it is about, and the rest keep whatever
    /// they had. What a panel whose content changes shape wants: it crosses to
    /// its new place and takes its new size at once.
    func testAMotionMayNameWhichValuesItIsAbout() {
        let renders = Renders()

        func panel(_ width: Double, _ colour: Color) -> Node {
            Border { Label("x") }
                .widthRequest(width)
                .backgroundColor(colour)
                .motion(.none, .size)
                .id("p")
                .body
        }

        renders.render(panel(100, Color("#000000")))
        let patch = renders.render(panel(300, Color("#FFFFFF")))

        XCTAssertEqual(patch.props[.widthRequest], .number(300))
        XCTAssertNil(patch.transitions[.widthRequest], "the size arrives")
        XCTAssertNotNil(patch.transitions[.backgroundColor], "the colour still travels")
    }

    /// And a rule may say a motion rather than none.
    func testARuleMaySayADifferentMotionRatherThanNone() {
        let renders = Renders()
        let own = Motion.spring(response: 240)

        func panel(_ fade: Double, _ width: Double) -> Node {
            Border { Label("x") }
                .opacity(fade)
                .widthRequest(width)
                .motion(own, .opacity)
                .id("p")
                .body
        }

        renders.render(panel(1, 100))
        let patch = renders.render(panel(0.2, 300))

        XCTAssertEqual(patch.transitions[.opacity]?.motion, own)
        XCTAssertEqual(patch.transitions[.widthRequest]?.motion, .standard,
                       "what no rule names travels the way everything else does")
    }

    /// The LAST rule that names a value is the one that answers for it, which
    /// is what a modifier written later means everywhere else here.
    func testTheLastRuleThatNamesAValueAnswersForIt() {
        let renders = Renders()

        func panel(_ width: Double) -> Node {
            Border { Label("x") }
                .widthRequest(width)
                .motion(.none, .size)
                .motion(.eased(500), .width)
                .id("p")
                .body
        }

        renders.render(panel(100))
        let patch = renders.render(panel(300))

        XCTAssertEqual(patch.transitions[.widthRequest]?.motion, .eased(500))
    }

    /// A LAYOUT says which parts of a child's place travel, since a place is
    /// not a property and cannot carry a motion beside it.
    func testALayoutSaysWhichPartsOfAPlaceTravel() {
        let renders = Renders()

        let patch = renders.render(
            VStack { Label("x") }.motion(.none, .size).id("s").body)

        XCTAssertEqual(patch.lanes, .place, "the corner travels; the sides arrive")
    }

    /// A gradient is the same picture in different colours, so it crosses -
    /// which is what keeps a theme change uniform.
    func testAGradientTravels() {
        let renders = Renders()

        func panel(_ from: Color) -> Node {
            VStack { Label("x") }
                .background(.linearGradient([
                    GradientStop(from, 0),
                    GradientStop(Color("#FFFFFF"), 1),
                ]))
                .id("p")
                .body
        }

        renders.render(panel(Color("#000000")))
        let patch = renders.render(panel(Color("#FF0000")))

        XCTAssertNotNil(patch.transitions[.background])
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

    // ---- One transform, about the view's own centre -------------------------

    /// ONE TRANSFORM, AND THE ORDER IT IS WRITTEN IN DOES NOT CHANGE IT.
    ///
    /// That is the guarantee rather than a convenience: each part accumulates
    /// into its own number - moves add, turns in the plane add, sizes multiply -
    /// so there is no chain that composes into a SHEAR, which is the one affine
    /// transform no platform here has a property to draw. What comes out is
    /// MAUI's own five, and the same five on every platform.
    func testATransformIsTheSameWhicheverOrderItIsWrittenIn() throws {
        let renders = Renders()

        func tree(_ built: @escaping (ViewTransform) -> ViewTransform) -> Node {
            stack([Label("x").transform(built).id("one").body], id: "root")
        }

        let one = renders.render(tree { $0.rotate(14).scale(0.9).translate(100, 200) })
        let props = try XCTUnwrap(one.child("one")?.props)

        XCTAssertEqual(props[.rotation], .number(14))
        XCTAssertEqual(props[.scaleX], .number(0.9))
        XCTAssertEqual(props[.scaleY], .number(0.9))
        XCTAssertEqual(props[.translationX], .number(100))
        XCTAssertEqual(props[.translationY], .number(200))

        // The same transform said backwards is the same transform.
        let other = Renders()
            .render(tree { $0.translate(100, 200).scale(0.9).rotate(14) })

        XCTAssertEqual(other.child("one")?.props, props)
    }

    /// A TURN IS DRAWN FLAT, and that is what makes it mean the same picture
    /// everywhere: a rectangle turned by an angle is a rectangle cos(angle) as
    /// wide. `.rotationY` is the other reading of a turn, and every platform
    /// projects that one through a camera it chooses for itself.
    func testATurnIsWhatATurnedRectangleLooksLike() {
        let renders = Renders()

        let patch = renders.render(stack([
            Label("x").transform { $0.turn(60).tilt(60) }.id("one").body,
        ], id: "root"))

        let props = patch.child("one")?.props

        XCTAssertEqual(props?[.scaleX]?.number ?? 0, 0.5, accuracy: 0.0005)
        XCTAssertEqual(props?[.scaleY]?.number ?? 0, 0.5, accuracy: 0.0005)

        // Past its own edge a view is showing its back, which is not a picture
        // this can make - so the turn stops there rather than folding through.
        let past = Renders().render(stack([
            Label("x").transform { $0.turn(200) }.id("one").body,
        ], id: "root"))

        XCTAssertEqual(past.child("one")?.props[.scaleX]?.number ?? 1, 0, accuracy: 0.0005)
    }

    // ---- A layout of the author's own ---------------------------------------

    /// One closure is the whole layout: it is handed which view this is, how
    /// many there are and the room, and what it answers is where that view
    /// goes.
    func testAPlacedLayoutPutsEachViewWhereItsArithmeticSays() {
        let renders = Renders()

        func tree() -> Node {
            PlacedLayout([1, 2, 3], id: \.self, at: { index, count, room in
                Placement(
                    Rect(room.width / Double(count) * Double(index), 0, 40, 40),
                    opacity: 1 - Double(index) / 4,
                    zIndex: 3 - index
                ) {
                    $0.scale(1 - Double(index) / 10).turn(Double(index) * 20)
                }
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

        // AND HOW IT IS TURNED, which is the rest of a placement: each of these
        // is a property of the view itself, written onto it from the same one
        // line of arithmetic - so a gallery whose cards face the middle needs
        // no second pass over the run and nothing on the views themselves.
        // ONE TRANSFORM, and every part of it lands on the property MAUI has
        // for it: a size across is `scale` times what the turn left of the
        // width, which is cos(20 degrees) - and the whole of it is arithmetic
        // this side did, so it is the same picture on every platform.
        XCTAssertEqual(placed[1].props[.scaleY], .number(0.9))
        XCTAssertEqual(placed[1].props[.scaleX]?.number ?? 0, 0.9 * 0.9397, accuracy: 0.0005)
        XCTAssertEqual(placed[1].props[.rotation], .number(0))
        XCTAssertEqual(placed[1].props[.opacity], .number(0.75))
        XCTAssertEqual(placed[1].props[.zIndex], .number(2))

        // The ones nothing was said about carry what "as it was drawn" means,
        // rather than being left off - a placement that stopped turning a card
        // has to put it back.
        XCTAssertEqual(placed[0].props[.rotation], .number(0))
        XCTAssertEqual(placed[0].props[.scaleX], .number(1))
        XCTAssertEqual(placed[0].props[.scaleY], .number(1))
        XCTAssertEqual(placed[0].props[.translationX], .number(0))
        XCTAssertEqual(placed[0].props[.translationY], .number(0))

        // AND A TURN OUT OF THE PLANE IS NOT A PLACEMENT'S TO GIVE: every
        // platform projects one through a camera of its own, so the same
        // number would be a different picture on each.
        XCTAssertNil(placed[0].props[.rotationX])
        XCTAssertNil(placed[0].props[.rotationY])

        // The ANCHOR is not a placement's to write: it is worked out from the
        // view's own size, which Android reads at the moment the property is
        // written and before this layout has given the view one.
        XCTAssertNil(placed[0].props[.anchorX])
        XCTAssertNil(placed[0].props[.anchorY])
    }

    /// A placement's turn and fade are ordinary properties of the view, so they
    /// are held still with the places when the layout says so - a card facing
    /// the middle has to follow the hand as exactly as one sliding along.
    func testAHeldPlacedLayoutHoldsTheTurnAsWellAsThePlace() {
        let renders = Renders()

        func tree(_ still: Bool) -> Node {
            let fan = PlacedLayout([1], id: \.self, at: { _, _, _ in
                Placement(Rect(0, 0, 40, 40)) { $0.turn(20) }
            }) { number in
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

        XCTAssertEqual(layout(renders.render(tree(true)))?.children.first?.motion, Motion.none)

        // And the inherited law is left OFF the children: it is what every view
        // is until told otherwise, and a run of a hundred cards would otherwise
        // spend bytes on every one of them to repeat the default.
        XCTAssertNil(layout(renders.renderFromScratch(tree(false)))?.children.first?.motion)
    }

    /// A layout of your own moves like every other one, and is held still the
    /// same way - which a placement worked out from something the reader is
    /// dragging wants.
    func testAPlacedLayoutSaysHowItsViewsTravel() {
        let renders = Renders()

        func tree(_ still: Bool) -> Node {
            let fan = PlacedLayout([1], id: \.self, at: { _, _, _ in
                Placement(Rect(0, 0, 40, 40))
            }) { number in
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
