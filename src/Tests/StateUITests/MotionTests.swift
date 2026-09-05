// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A VALUE THAT CHANGES TRAVELS. What these pin is the Swift half of that: which
// property changes get a motion written beside them, which get none, and what
// the numbers in one are.
//
// The rule is one sentence - every property of a CONTINUING element whose value
// has a half-way - and everything below is one of the ways out of it: an element
// being described for the first time, a value with no half-way, a place or a
// count, a property the library computes, and a READING a control wrote back,
// which arrives because a value following a finger must not lag behind it.
//
// The host's half is MotionTests.cs.

import StateUIWireProbe
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

        // EVERY ONE OF THEM, not just the one above. What this holds is that
        // the DIFFER honours the whole list rather than the one property a
        // test happened to write: taking the check out of Diff.swift fails
        // here naming `maxLength`, `gridRowSpan` and `position`.
        //
        // WHAT IT CANNOT HOLD is a member LEAVING the list, since the list is
        // what it walks. That belongs to whoever removes one, and `Prop.
        // unmoved` says so where it is declared.
        //
        // A NUMBER is what each is given, because a number is exactly the
        // value that would travel if the property were not on the list.
        for property in Prop.unmoved {
            let alone = Renders()

            alone.render(Label("x").setValue(property, .number(0)).id("l").body)

            let moved = alone.render(Label("x").setValue(property, .number(3)).id("l").body)

            XCTAssertEqual(
                moved.props[property], .number(3),
                "\(property.name) did not change at all, so this proves nothing")
            XCTAssertTrue(
                moved.transitions.isEmpty,
                "\(property.name) travelled, and nothing on Prop.unmoved may")
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

    /// THE ONE SNAP NOTHING ELSE PROTECTS, and it is written through the
    /// CONTROL because the control is what arms the value it borrows.
    ///
    /// A two-way input writes every report straight back into the state it was
    /// described from, and a value following a finger is re-answered many times
    /// a second - so a drag report left to the ordinary motion would walk the
    /// thumb back toward the finger a fifth of a second late, on every report.
    /// The mark the control sets is the only thing that tells that motion to
    /// leave `.value` alone.
    ///
    /// Reached any other way - a modifier that arms a binding of its own - this
    /// would be a test of a different road, and would go on passing while the
    /// lag was live.
    func testADraggedSliderWritesItsReportBackWithoutTravelling() {
        let volume = State(wrappedValue: 0.5)
        let renders = Renders()

        func panel() -> Node { Slider(volume.projectedValue).id("s").body }

        let first = renders.render(panel())

        renders.fire(first.events?[.valueChanged] ?? -1, with: [.number(0.7)])
        let dragged = renders.render(panel())

        XCTAssertEqual(dragged.props[.value], .number(0.7), "the report was written back")
        XCTAssertNil(dragged.transitions[.value], "and it landed at once")

        // ONE WRITE AND NOT A SETTING: the mark is spent on the render that
        // takes it, so an author's own write to the very same state travels.
        volume.wrappedValue = 1
        let sent = renders.render(panel())

        XCTAssertNotNil(sent.transitions[.value], "and the next write travels")
    }

    /// A `Stepper` is the other control that arms what it borrows, and it
    /// answers the same way - so the guard covers both of them rather than the
    /// one that happened to be written first.
    func testASteppedValueIsWrittenBackWithoutTravelling() {
        let servings = State(wrappedValue: 2.0)
        let renders = Renders()

        func panel() -> Node { Stepper(servings.projectedValue).id("s").body }

        let first = renders.render(panel())

        renders.fire(first.events?[.valueChanged] ?? -1, with: [.number(3)])
        let stepped = renders.render(panel())

        XCTAssertEqual(stepped.props[.value], .number(3), "the report was written back")
        XCTAssertNil(stepped.transitions[.value], "and it landed at once")
    }

    // ---- One transform, about the view's own centre -------------------------

    /// ONE TRANSFORM, HAPPENING IN THE ORDER IT IS WRITTEN. Each part is done
    /// to what the parts before it made - so a move written BEFORE a turn is
    /// swung round by it, and one written after is not - and all of the
    /// arithmetic is this side's, so the chain is the same numbers and the
    /// same picture on every platform. What comes out is MAUI's own five.
    func testATransformHappensInTheOrderItIsWritten() throws {
        let renders = Renders()

        func tree(_ built: ViewTransform) -> Node {
            stack([Label("x").transform(built).id("one").body], id: "root")
        }

        let one = renders.render(tree(.rotate(90).translate(100, 0)))
        let props = try XCTUnwrap(one.child("one")?.props)

        // The move came AFTER the turn, so it is a plain hundred to the right.
        XCTAssertEqual(props[.rotation]?.number ?? 0, 90, accuracy: 0.000001)
        XCTAssertEqual(props[.translationX]?.number ?? 0, 100, accuracy: 0.000001)
        XCTAssertEqual(props[.translationY]?.number ?? 1, 0, accuracy: 0.000001)
        XCTAssertEqual(props[.scaleX]?.number ?? 0, 1, accuracy: 0.000001)
        XCTAssertEqual(props[.scaleY]?.number ?? 0, 1, accuracy: 0.000001)

        // Written first, the same move is swung round by the turn - and grown
        // by a sizing after it, because each part happens to the whole of what
        // came before.
        let other = Renders()
            .render(tree(.translate(100, 0).rotate(90).scale(2)))
        let swung = try XCTUnwrap(other.child("one")?.props)

        XCTAssertEqual(swung[.rotation]?.number ?? 0, 90, accuracy: 0.000001)
        XCTAssertEqual(swung[.translationX]?.number ?? 1, 0, accuracy: 0.000001)
        XCTAssertEqual(swung[.translationY]?.number ?? 0, 200, accuracy: 0.000001)
        XCTAssertEqual(swung[.scaleX]?.number ?? 0, 2, accuracy: 0.000001)
        XCTAssertEqual(swung[.scaleY]?.number ?? 0, 2, accuracy: 0.000001)
    }

    /// A CHANGED TRANSFORM TRAVELS: what it writes is five ordinary
    /// interpolable properties, so the differ gives each changed one a
    /// transitions entry like any other value - lane by lane, at the
    /// application's motion.
    func testAChangedTransformTravels() throws {
        let renders = Renders()

        func tree(_ built: ViewTransform) -> Node {
            stack([Label("x").transform(built).id("one").body], id: "root")
        }

        renders.render(tree(.identity))
        let patch = try XCTUnwrap(renders.render(tree(.rotate(45).scale(2))).child("one"))

        for prop in [Prop.rotation, .scaleX, .scaleY] {
            let travel = patch.transitions[prop]
            XCTAssertEqual(travel?.motion, .standard, "\(prop) travels")
        }

        // The moves did not change, so they are not on the message at all.
        XCTAssertNil(patch.props[.translationX])
        XCTAssertNil(patch.transitions[.translationX])
    }

    /// THE ONE CHAIN THE FIVE PROPERTIES CANNOT CARRY WHOLE is a one-axis
    /// sizing of a view turned EARLIER, which slants it into a parallelogram
    /// no platform here has a property to draw. The turn, the move and both
    /// sizes are kept; the slant alone is left out - and this test is the
    /// statement of that limit.
    func testAOneAxisSizingOfATurnedViewKeepsEverythingButTheSlant() throws {
        let renders = Renders()

        let patch = renders.render(stack([
            Label("x").transform(.rotate(45).scaleX(2)).id("one").body,
        ], id: "root"))

        let props = try XCTUnwrap(patch.child("one")?.props)

        // The across axis of the turned view, doubled: its direction is what
        // the rotation reads back, its length the width.
        XCTAssertEqual(props[.rotation]?.number ?? 0, 26.5650511770780, accuracy: 0.000001)
        XCTAssertEqual(props[.scaleX]?.number ?? 0, 1.5811388300842, accuracy: 0.000001)
        XCTAssertEqual(props[.scaleY]?.number ?? 0, 1.2649110640674, accuracy: 0.000001)
    }

    /// EVERY PART IS ALSO A STARTING POINT, and it has to mean the same thing
    /// as the part written onto a view as it was drawn - seven one-line statics
    /// beside seven instance methods of the same names being exactly where a
    /// `scaleX` delegating to `scaleY` would sit unnoticed.
    func testAPartWrittenFirstIsThePartWrittenOnAViewAsItWasDrawn() {
        let plain = ViewTransform.identity

        XCTAssertEqual(ViewTransform.translate(10, 20), plain.translate(10, 20))
        XCTAssertEqual(ViewTransform.rotate(14), plain.rotate(14))
        XCTAssertEqual(ViewTransform.scale(0.5), plain.scale(0.5))
        XCTAssertEqual(ViewTransform.scaleX(0.5), plain.scaleX(0.5))
        XCTAssertEqual(ViewTransform.scaleY(0.5), plain.scaleY(0.5))
        XCTAssertEqual(ViewTransform.turn(40), plain.turn(40))
        XCTAssertEqual(ViewTransform.tilt(40), plain.tilt(40))

        // And the two sizings are about different sides, which is the mistake
        // the check above exists to catch.
        XCTAssertNotEqual(ViewTransform.scaleX(0.5), ViewTransform.scaleY(0.5))
        XCTAssertNotEqual(ViewTransform.turn(40), ViewTransform.tilt(40))
    }

    /// A TURN IS DRAWN FLAT, and that is what makes it mean the same picture
    /// everywhere: a rectangle turned by an angle is a rectangle cos(angle) as
    /// wide. `.rotationY` is the other reading of a turn, and every platform
    /// projects that one through a camera it chooses for itself.
    func testATurnIsWhatATurnedRectangleLooksLike() {
        let renders = Renders()

        let patch = renders.render(stack([
            Label("x").transform(.turn(60).tilt(60)).id("one").body,
        ], id: "root"))

        let props = patch.child("one")?.props

        XCTAssertEqual(props?[.scaleX]?.number ?? 0, 0.5, accuracy: 0.0005)
        XCTAssertEqual(props?[.scaleY]?.number ?? 0, 0.5, accuracy: 0.0005)

        // Past its own edge a view is showing its back, which is not a picture
        // this can make - so the turn stops there rather than folding through.
        let past = Renders().render(stack([
            Label("x").transform(.turn(200)).id("one").body,
        ], id: "root"))

        XCTAssertEqual(past.child("one")?.props[.scaleX]?.number ?? 1, 0, accuracy: 0.0005)
    }

    // ---- A layout of the author's own ---------------------------------------

    func testAPlacedLayoutSaysHowItsViewsTravel() {
        let renders = Renders()

        let run = State(wrappedValue: PlacedRun(), asks: .never)

        func tree(_ still: Bool) -> Node {
            let fan = PlacedLayout([1], id: \.self) { number in
                Label("\(number)")
            }
            .placement(run.projectedValue)

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

    // ---- The bytes ----------------------------------------------------------

    /// THE ORDINARY CASE, WRITTEN DOWN. A value that simply changed is the
    /// motion almost every motion in an application is - nobody started it and
    /// nobody waits for it - and this is the one that crosses as bytes.
    ///
    /// Two messages, because a motion is what a CONTINUING element does: the
    /// first describes the panel and carries none, the second changes one
    /// number and carries the walk to it. The C# half applies these very
    /// files.
    func testAValueThatTravelsIsWrittenDown() throws {
        let differ = Differ()
        let dictionary = WireDictionary()
        let names = WireNames()

        let first = differ.reconcile(nil, with: panel(1))
        let opening = Wire.encode(first.patch, generation: 1, dictionary: dictionary)

        try Fixtures.check(
            opening,
            sidecar: WireProbe.dumpMessage(opening, names: names),
            against: "travelling-first")

        let moved = differ.reconcile(first.node, with: panel(0.25))
        let bytes = Wire.encode(moved.patch, generation: 2, dictionary: dictionary)

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: names),
            against: "travelling")
    }

    // ---- The vocabulary itself ---------------------------------------------

    func testTheLawsCarryTheNumbersTheyNeed() {
        XCTAssertEqual(Motion.eased(400, .cubicIn).millis, 400)
        XCTAssertEqual(Motion.eased(400, .cubicIn).curve, .cubicIn)

        XCTAssertEqual(Motion.spring(response: 260, damping: 0.7).millis, 260)
        XCTAssertEqual(Motion.spring(response: 260, damping: 0.7).factor, 0.7)
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

        // ASKED TO: damping under one is what overshoot IS, and the floor is
        // 0.05 rather than nought - a spring with no damping at all never
        // arrives.
        XCTAssertEqual(Motion.spring(damping: 0.4).factor, 0.4)
        XCTAssertEqual(Motion.spring(damping: 0).factor, 0.05)
    }
}
