// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's own carousel: what it places, what it describes, and when it
// takes the offset over.
//
// A CarouselView is made of controls that already exist - a ScrollView, an
// AbsoluteLayout, the cards - so there is nothing on the C# side to check it
// against, and everything worth pinning is on this side: how a card is cut
// from the visible area, which cards are described at all, and what the one
// number the scroller sends it makes it do.

import XCTest

@testable import StateUI

final class CarouselTests: XCTestCase {
    /// A carousel of numbered cards, each showing its own number.
    private func carousel(_ count: Int) -> CarouselView<Range<Int>, Int> {
        CarouselView(0..<count) { number in
            Label("\(number)")
        }
    }

    /// One frame report: eight numbers, of which these tests use the size.
    private func frame(width: Double, height: Double) -> [PropValue] {
        [.numbers([0, 0, width, height, 0, 0, 0, 0])]
    }

    /// The AbsoluteLayout the cards are placed in - the scroller's only child.
    private func placer(_ patch: Patch) -> Patch {
        patch.children.first { $0.type == .absoluteLayout } ?? patch
    }

    /// The cards, read off their identities.
    private func shown(_ patch: Patch) -> [String] {
        placer(patch).children.compactMap {
            if case .manual(let identity) = $0.id { return identity }
            return nil
        }
    }

    /// Renders, tells the scroller how big it is, and renders again - which is
    /// the state a carousel is in the moment it is on screen.
    private func measured(
        _ renders: Renders,
        _ tree: () -> Node,
        width: Double = 400,
        height: Double = 300
    ) -> (patch: Patch, first: Patch, snap: Int) {
        let first = renders.render(tree())
        let snap = first.events?[.snapItemChanged] ?? -1

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1,
                                   with: frame(width: width, height: height)))

        return (renders.render(tree()), first, snap)
    }

    /// A card is a FRACTION of the visible area, and the run is two slots
    /// longer than the cards - one empty at each end.
    func testACardIsCutFromTheVisibleArea() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(3).body })

        // 400 wide, three quarters of it a card, twelve between them: two
        // slots for three cards, plus the viewport the pads add up to.
        XCTAssertEqual(placer(showing.patch).props[.widthRequest], .number(2 * 312 + 400))
        XCTAssertEqual(placer(showing.patch).props[.heightRequest], .number(300))

        let cards = placer(showing.patch).children

        // The first card starts one PAD in - half a viewport less half a card
        // - which is what centres it at an offset of nothing.
        XCTAssertEqual(cards[0].props[.absoluteLayoutBounds], Rect(50, 0, 300, 1).propValue)
        XCTAssertEqual(cards[1].props[.absoluteLayoutBounds], Rect(362, 0, 300, 1).propValue)

        // The card's own length is in device units; the side across the axis
        // is the whole of the layout. Read off the FIRST render: the flags do
        // not change, and a patch carries what changed.
        XCTAssertEqual(placer(showing.first).children[0].props[.absoluteLayoutFlags],
                       AbsoluteLayoutFlags.heightProportional.propValue)
    }

    /// The fraction and the spacing are the author's, and the whole run is
    /// measured from them.
    func testTheFractionAndTheSpacingAreTheAuthors() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(4).itemFraction(0.5).itemSpacing(20).body })

        // Half of 400, twenty between: a slot is 220, three of them for four
        // cards, and the pads are 100 each.
        XCTAssertEqual(placer(showing.patch).props[.widthRequest], .number(3 * 220 + 400))
        XCTAssertEqual(placer(showing.patch).children[0].props[.absoluteLayoutBounds],
                       Rect(100, 0, 200, 1).propValue)
    }

    /// Running down places the cards down the other axis, and the run's length
    /// is the height.
    func testRunningDownPlacesTheCardsDownTheOtherAxis() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(3).orientation(.vertical).body })

        // 300 tall now, so a card is 225, a slot is 237 and a pad is 37.5.
        XCTAssertEqual(placer(showing.patch).props[.heightRequest], .number(2 * 237 + 300))
        XCTAssertEqual(placer(showing.patch).props[.widthRequest], .number(400))
        XCTAssertEqual(placer(showing.patch).children[0].props[.absoluteLayoutBounds],
                       Rect(0, 37.5, 1, 225).propValue)
        XCTAssertEqual(placer(showing.first).children[0].props[.absoluteLayoutFlags],
                       AbsoluteLayoutFlags.widthProportional.propValue)
    }

    /// Turning a carousel to run DOWN needs no new measurement.
    ///
    /// The frame is the same rectangle either way, so no report follows the
    /// turn - which is why the two sides are kept as width and height and the
    /// axis picks which of them a card is a fraction of. Kept because it did
    /// not: a carousel measured sideways and then turned drew nothing at all.
    func testTurningItToRunDownNeedsNoNewMeasurement() {
        let renders = Renders()
        let sideways = State(true)

        let tree = {
            self.carousel(3)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        let showing = measured(renders, tree)
        XCTAssertEqual(placer(showing.patch).props[.widthRequest], .number(2 * 312 + 400))

        sideways.wrappedValue = false
        let turned = renders.render(tree())

        // 300 tall now, and not one frame report in between.
        XCTAssertEqual(placer(turned).props[.heightRequest], .number(2 * 237 + 300))
        XCTAssertEqual(placer(turned).children[0].props[.absoluteLayoutBounds],
                       Rect(0, 37.5, 1, 225).propValue)
    }

    /// Only the card the scroller NAMES and its neighbours are described - the
    /// rest of a long deck is not built and not sent.
    func testOnlyTheCardInViewAndItsNeighboursAreDescribed() async {
        let renders = Renders()
        let shown = State(7)
        let tree = { self.carousel(40).position(shown.projectedValue).body }
        let showing = measured(renders, tree)

        laid(renders, showing)
        await landing(renders)

        // At card 7, which is where the position says it is.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(7)))

        XCTAssertEqual(self.shown(renders.render(tree())), ["5", "6", "7", "8", "9"])
    }

    /// And at an end the neighbours are on one side only.
    func testAnEndHasNeighboursOnOneSide() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(40).body })

        XCTAssertEqual(self.shown(showing.patch), ["0", "1", "2"])
    }

    /// A carousel opened AT a far card describes where it is and where it is
    /// going, and nothing of the run between them.
    func testACarouselOpenedFarAlongDescribesBothEndsOfTheJump() {
        let renders = Renders()
        let shown = State(20)
        let showing = measured(renders, { self.carousel(40).position(shown.projectedValue).body })

        // The offset is still at the start and the position is twenty cards
        // on: two windows, not the twenty-five cards between them.
        XCTAssertEqual(
            self.shown(showing.patch), ["0", "1", "2", "18", "19", "20", "21", "22"])
    }

    /// A carousel with no items at all shows what stands in for them.
    func testAnEmptyCarouselShowsItsEmptyView() {
        let renders = Renders()
        let patch = renders.render(
            CarouselView(0..<0) { Label("\($0)") }
                .emptyView(Label("Nothing to leaf through"))
                .body)

        XCTAssertEqual(patch.children.first?.props[.text], .string("Nothing to leaf through"))
    }

    /// The scroller saying which card it is nearest - the carousel's one input.
    private func nearest(_ index: Int) -> [PropValue] {
        [.number(Double(index))]
    }

    /// The scroll acts queued, as the offset each asked for along the axis.
    private func glides() -> [Double] {
        drainedActs().filter { $0.name == "scrollToAsync" }.compactMap { $0.arguments[1].number }
    }

    /// The scroller saying it has stopped - the carousel's other input, and
    /// the one that moves the window it describes.
    private func rested(_ patch: Patch) -> Int {
        patch.events?[.scrollStopped] ?? -1
    }

    /// The run as LAID OUT: the layout answers with the length the tree asked
    /// of it, which is what says an offset in it can be reached - and what a
    /// report about the run is believed against. On a screen this lands with
    /// the first layout pass; a test that skips it stands in a world where
    /// nothing was ever drawn, and a report fired there is rightly refused.
    private func laid(
        _ renders: Renders,
        _ showing: (patch: Patch, first: Patch, snap: Int),
        width: Double = 400,
        height: Double = 300
    ) {
        var run = (width: width, height: height)

        if case .number(let asked)? = placer(showing.patch).props[.widthRequest], asked > 0 {
            run.width = asked
        }

        if case .number(let asked)? = placer(showing.patch).props[.heightRequest], asked > 0 {
            run.height = asked
        }

        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: run.width, height: run.height)))
    }

    /// Lands whatever movement the carousel has just asked the host for - the
    /// walk a re-centring starts the moment the run is laid out - so the test
    /// stands where the screen does: laid out, walked, and at rest.
    private func landing(_ renders: Renders) async {
        for done in drainedActs().compactMap(\.completion) {
            ReplyBuffer.current = .finished([])
            XCTAssertTrue(Renderer.shared.dispatch(done))
        }

        _ = await settle()
    }

    /// A carousel of `count` cards, standing still on `card` with the window
    /// drawn round it - which is where a swipe starts from.
    private func standing(
        _ renders: Renders,
        _ tree: @escaping () -> Node,
        on card: Int
    ) async -> (patch: Patch, first: Patch, snap: Int) {
        let showing = measured(renders, tree)

        laid(renders, showing)
        await landing(renders)

        XCTAssertTrue(renders.fire(showing.snap, with: nearest(card)))
        XCTAssertTrue(renders.fire(rested(showing.first)))

        return showing
    }

    /// AN ORDINARY SWIPE DESCRIBES NOTHING NEW. A card either side is already
    /// there, so crossing into one of them builds no control at all - which is
    /// what keeps the movement smooth: every card entering the window is a
    /// control the platform has to make, and making one under a finger is
    /// seen.
    func testASwipeOfOneCardDescribesNothingNew() async {
        let renders = Renders()
        let tree = { self.carousel(9).body }
        let showing = await standing(renders, tree, on: 4)

        XCTAssertEqual(self.shown(renders.renderFromScratch(tree())), ["2", "3", "4", "5", "6"])

        // One card on, and the movement still under way.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(5)))

        XCTAssertEqual(self.shown(renders.renderFromScratch(tree())), ["2", "3", "4", "5", "6"])
    }

    /// And the window moves when the movement ENDS, which is where the card
    /// the next swipe will need can be built without any of it being seen.
    func testTheWindowMovesWhenTheScrollerStops() async {
        let renders = Renders()
        let tree = { self.carousel(9).body }
        let showing = await standing(renders, tree, on: 4)

        XCTAssertTrue(renders.fire(showing.snap, with: nearest(5)))
        XCTAssertTrue(renders.fire(rested(showing.first)))

        XCTAssertEqual(self.shown(renders.renderFromScratch(tree())), ["3", "4", "5", "6", "7"])
    }

    /// A swipe that OUTRUNS the window has nothing described in front of it,
    /// so that one widens in flight - the alternative being a card of empty
    /// space flying past.
    func testASwipePastTheEdgeOfTheWindowDescribesInFlight() async {
        let renders = Renders()
        let tree = { self.carousel(9).body }
        let showing = await standing(renders, tree, on: 4)

        XCTAssertTrue(renders.fire(showing.snap, with: nearest(6)))

        XCTAssertEqual(self.shown(renders.renderFromScratch(tree())), ["4", "5", "6", "7", "8"])
    }

    /// The carousel tells the scroller to rest on multiples of a SLOT, which
    /// is what makes the platform's own deceleration end on a card - and it
    /// says nothing else about scrolling at all.
    func testTheSlotIsWhatTheScrollerIsToldAndTheOnlyThing() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(5).body })

        XCTAssertEqual(showing.patch.props[.snapInterval], .number(312))
        XCTAssertNil(showing.patch.props[.scrollStep],
                     "a carousel that hears its cards has nothing to say about offsets")
    }

    /// A swipe carries HALF of what the platform would throw a scroller, which
    /// is what makes an ordinary flick mean the next card rather than the
    /// fourth - and the author may say otherwise.
    func testASwipeCarriesHalfThePlatformsThrow() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(5).body })

        XCTAssertEqual(showing.patch.props[.scrollMomentum], .number(0.5))

        let further = measured(Renders(), { self.carousel(5).momentum(0.9).body })

        XCTAssertEqual(further.patch.props[.scrollMomentum], .number(0.9))
    }

    /// The card the scroller names is the position, written as it is named -
    /// which is while the movement is still under way, and without the
    /// carousel asking the scroller for anything.
    func testTheCardTheScrollerNamesIsThePosition() async {
        let renders = Renders()
        let shown = State(0)
        let showing = measured(renders, { self.carousel(5).position(shown.projectedValue).body })

        laid(renders, showing)
        await landing(renders)

        XCTAssertTrue(renders.fire(showing.snap, with: nearest(2)))

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(glides(), [], "the carousel asked for a movement the scroller was making")
    }

    /// There is no cap: the scroller carries a throw as far as its speed
    /// deserves, and the cards it is passing are described as it names them.
    func testAThrowIsFollowedWhereverTheScrollerCarriesIt() async {
        let renders = Renders()
        let shown = State(0)
        let tree = { self.carousel(9).position(shown.projectedValue).body }
        let showing = measured(renders, tree)

        laid(renders, showing)
        await landing(renders)

        XCTAssertTrue(renders.fire(showing.snap, with: nearest(3)))

        XCTAssertEqual(shown.wrappedValue, 3)
        XCTAssertEqual(self.shown(renders.render(tree())), ["1", "2", "3", "4", "5"])
    }

    /// A card named TWICE is one message: the second says nothing new, so
    /// nothing is written and nobody is told.
    func testTheSameCardNamedAgainChangesNothing() {
        let renders = Renders()
        let landings = State(0)

        let showing = measured(renders, {
            self.carousel(5).onPositionChanged { _ in landings.wrappedValue += 1 }.body
        })

        laid(renders, showing)

        XCTAssertTrue(renders.fire(showing.snap, with: nearest(2)))
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(2)))

        XCTAssertEqual(landings.wrappedValue, 1)
    }

    /// A position somebody ASSIGNED moves the carousel; the same position
    /// coming back from the scroller does not, or the two would chase each
    /// other - a glide reporting the card it arrived at, which arms a glide.
    func testAnAssignedPositionGlidesAndAReportedOneDoesNot() {
        let renders = Renders()
        let shown = State(0)
        let tree = { self.carousel(5).position(shown.projectedValue).body }
        let showing = measured(renders, tree)
        _ = drainedActs()

        // Assigned: the carousel takes itself there.
        shown.wrappedValue = 3
        renders.render(tree())
        XCTAssertEqual(glides(), [3 * 312])

        // And the scroller arriving says the same number back, which moves
        // nothing.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(3)))
        renders.render(tree())
        XCTAssertEqual(glides(), [])
    }

    /// A carousel MOVED BY ASSIGNMENT goes on describing the card it was sent
    /// to, however many moves in a row it is given.
    ///
    /// A jump reports the card it landed on and nothing in between, and it
    /// comes to rest nowhere - so a window that waits to be told the movement
    /// ended waits for ever, and the deck is left described where it no longer
    /// is. Which is a blank carousel: the reader presses Next, the scroller
    /// goes, and there is nothing at the other end.
    func testCardsAssignedOneAfterAnotherStayDescribed() async {
        let renders = Renders()
        let shown = State(0)
        let tree = { self.carousel(9).position(shown.projectedValue).isScrollAnimated(false).body }
        let showing = await standing(renders, tree, on: 0)

        for card in 1...3 {
            shown.wrappedValue = card
            renders.render(tree())

            // The scroller arrives and says which card it is on. Nothing rests:
            // a jump is not a movement the platform ran.
            XCTAssertTrue(renders.fire(showing.snap, with: nearest(card)))
        }

        XCTAssertTrue(
            self.shown(renders.renderFromScratch(tree())).contains("3"),
            "the card the carousel was sent to is not described")
    }

    /// TURNING IT KEEPS THE CARDS THEMSELVES - the run is re-placed on the
    /// other axis, not built again.
    ///
    /// The rows are kept BY THE BRANCH they were written in, so a turn written
    /// as two branches is a layout thrown away and every card on screen made a
    /// second time. Read off the element the layout is: same element, same
    /// controls.
    func testTurningItPlacesTheCardsAgainRatherThanBuildingThem() {
        let renders = Renders()
        let sideways = State(true)
        let tree = {
            self.carousel(9)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        let showing = measured(renders, tree)
        let before = placer(showing.first).id

        sideways.wrappedValue = false

        XCTAssertEqual(placer(renders.renderFromScratch(tree())).id, before,
                       "the turn built a new layout, and every card in it")
    }

    /// A card the list was SENT to is a card it is ON: whoever is watching
    /// hears about it and a deck near its end asks for more.
    ///
    /// The reader pressing Next and the reader swiping arrive at the same
    /// place, so the same things follow. They did not: a move this side made
    /// was heard back from the platform as a card already arrived at, and
    /// everything hanging off arriving was skipped - so a deck stepped through
    /// with the buttons never grew.
    func testACardTheListWasSentToAsksForMore() async throws {
        let renders = Renders()
        let shown = State(0)
        let asked = State(0)
        let tree = {
            self.carousel(4)
                .position(shown.projectedValue)
                .remainingItemsThreshold(1)
                .onRemainingItemsThresholdReached { asked.wrappedValue += 1 }
                .body
        }

        _ = measured(renders, tree)
        _ = drainedActs()

        shown.wrappedValue = 2
        renders.render(tree())

        // The host performs the move and says it is done, which is the moment
        // the card is the one the list is on.
        let done = try XCTUnwrap(drainedActs().compactMap(\.completion).first)
        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(done))
        await settle()

        XCTAssertEqual(asked.wrappedValue, 1, "a card one from the end asked for nothing")
    }

    /// And whoever asked to be told which card it settled on is told, however
    /// the card was reached.
    func testACardTheListWasSentToIsReported() async throws {
        let renders = Renders()
        let shown = State(0)
        let landed = State(-1)
        let tree = {
            self.carousel(5)
                .position(shown.projectedValue)
                .onPositionChanged { at in landed.wrappedValue = at }
                .body
        }

        _ = measured(renders, tree)
        _ = drainedActs()

        shown.wrappedValue = 3
        renders.render(tree())

        let done = try XCTUnwrap(drainedActs().compactMap(\.completion).first)
        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(done))
        await settle()

        XCTAssertEqual(landed.wrappedValue, 3)
    }

    /// TURNING THE CAROUSEL KEEPS THE CARD THE READER IS ON.
    ///
    /// The offset along the axis it has just been turned to is NOTHING - that
    /// axis was never scrolled - so the scroller names the first slot the
    /// moment the turn lands. That is not the reader moving: the list is
    /// already walking itself back to the card it was on, and a report about a
    /// walk this side started says nothing about where the reader wants to be.
    /// Believed, it took the position, the window and the author's binding to
    /// the first card and left the scroller where the walk had sent it - a
    /// carousel with nothing on screen.
    func testTurningItKeepsTheCardTheReaderIsOn() async {
        let renders = Renders()
        let shown = State(0)
        let sideways = State(true)
        let tree = {
            self.carousel(9)
                .position(shown.projectedValue)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        let showing = await standing(renders, tree, on: 6)
        XCTAssertEqual(shown.wrappedValue, 6)

        sideways.wrappedValue = false
        let turned = renders.renderFromScratch(tree())

        // The run is laid out at its new length, which is the moment the card
        // can be put back.
        XCTAssertTrue(renders.fire(placer(turned).events?[.frameChanged] ?? -1,
                                   with: frame(width: 400, height: 8 * 237 + 300)))
        renders.render(tree())

        // And the scroller names the first slot, the new axis standing at
        // nothing.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(0)))

        XCTAssertEqual(shown.wrappedValue, 6, "the turn threw the reader\'s card away")
        XCTAssertTrue(self.shown(renders.renderFromScratch(tree())).contains("6"),
                      "the card the reader is on is not described")
    }

    /// A carousel OPENED at a card takes itself there once it has been laid
    /// out, rather than describing both ends of the jump for ever.
    ///
    /// Nothing fires on the way in - a view appearing is not a value changing -
    /// so the move belongs to the first moment the run has a length an offset
    /// can be reached in, which is the same moment a turn or a resize is put
    /// right at.
    func testACarouselOpenedFarAlongTakesItselfThere() {
        let renders = Renders()
        let shown = State(20)
        let tree = { self.carousel(40).position(shown.projectedValue).body }
        let showing = measured(renders, tree)
        _ = drainedActs()

        // The run reports how long it was laid out, which is what says an
        // offset that far along can be reached at all.
        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: 39 * 312 + 400, height: 300)))
        renders.render(tree())

        XCTAssertEqual(glides(), [20 * 312], "the carousel never went to the card it was opened at")
    }

    /// A SQUARE carousel turned still puts the reader's card back.
    ///
    /// A card is the same fraction of either side, so in a square viewport the
    /// run is as long down as it was across and the step is the same number -
    /// neither can say the axis turned. What says it is the turn itself: the
    /// measured length and the re-centring latch are both about the axis they
    /// were taken along, so the turn forgets them and the layout's own report
    /// along the new axis is what lets the card be put back.
    func testTurningASquareCarouselStillPutsTheCardBack() async throws {
        let renders = Renders()
        let shown = State(0)
        let sideways = State(true)
        let tree = {
            self.carousel(9)
                .position(shown.projectedValue)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        let showing = measured(renders, tree, width: 400, height: 400)
        _ = drainedActs()

        // The run is laid out, and the opening re-centring spends its latch.
        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: 8 * 312 + 400, height: 400)))
        renders.render(tree())

        let opened = try XCTUnwrap(drainedActs().compactMap(\.completion).first)
        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(opened))
        await settle()

        // The reader swipes to card 6 and the movement ends.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(6)))
        XCTAssertTrue(renders.fire(rested(showing.first)))
        XCTAssertEqual(shown.wrappedValue, 6)

        sideways.wrappedValue = false
        let turned = renders.renderFromScratch(tree())
        renders.render(tree())

        // The run is laid out down at the SAME length it had across.
        XCTAssertTrue(renders.fire(placer(turned).events?[.frameChanged] ?? -1,
                                   with: frame(width: 400, height: 8 * 312 + 400)))
        renders.render(tree())

        // Running DOWN now, so the offset rides the y argument.
        let downward = drainedActs()
            .filter { $0.name == "scrollToAsync" }
            .compactMap { $0.arguments[2].number }

        XCTAssertEqual(downward, [6 * 312],
                       "a square carousel turned never put the reader's card back")
    }

    /// A PAGE RETURNED TO puts the reader's card back, however many beats the
    /// run takes to be laid out at its full length.
    ///
    /// The state that survives a page is not all of it: the position lives
    /// where the author put it - a page, an application - while the list's own
    /// memory of the scroller goes with the control, so a carousel opened again
    /// stands at the beginning believing nothing and is told a card far along.
    /// It is the same walk a carousel opened at a card makes, and it fails the
    /// same way if it is made too early: the run reports its length a beat
    /// SHORT, an offset past what is laid out is clamped by the platform, and
    /// the card the tree then believes in is one the scroller never reached -
    /// a carousel showing nothing, its dots on the last card, jumping to the
    /// first at a touch.
    func testAPageReturnedToPutsTheCardBack() {
        let renders = Renders()

        // The page's own state, which is what survived: card 8.
        let shown = State(8)
        let tree = { self.carousel(9).position(shown.projectedValue).body }

        let showing = measured(renders, tree)
        _ = drainedActs()

        // The run is laid out SHORT - one beat behind, which is where an
        // Android layout lands.
        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: 1200, height: 300)))
        renders.render(tree())

        XCTAssertEqual(glides(), [],
                       "the card was sent for on a run that could not reach it")

        // And then whole, which is the first moment card 8 can be reached.
        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: 8 * 312 + 400, height: 300)))
        renders.render(tree())

        XCTAssertEqual(glides(), [8 * 312], "the reader's card never came back")
        XCTAssertEqual(shown.wrappedValue, 8, "the position moved while nothing was moving")
    }

    /// A move REPLACED by a later one lands where the later one says.
    ///
    /// The host ends one movement to start the next, so the first move is
    /// answered too - and its answer is about a flight no longer under way.
    /// Believed, it wrote the OLD target over the position and the author's
    /// binding, and un-marked a flight still in the air, so a mid-glide report
    /// was believed too: two quick presses of Next landed one card short.
    func testAMoveReplacedByAnotherLandsWhereTheLaterOneSays() async throws {
        let renders = Renders()
        let shown = State(0)
        let tree = {
            self.carousel(9).position(shown.projectedValue).isScrollAnimated(false).body
        }

        _ = measured(renders, tree)
        _ = drainedActs()

        shown.wrappedValue = 3
        renders.render(tree())
        let first = try XCTUnwrap(drainedActs().compactMap(\.completion).first)

        shown.wrappedValue = 6
        renders.render(tree())
        let second = try XCTUnwrap(drainedActs().compactMap(\.completion).first)

        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(first))
        await settle()

        XCTAssertEqual(shown.wrappedValue, 6,
                       "the replaced move wrote its old target over the author's binding")

        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(second))
        await settle()

        XCTAssertEqual(shown.wrappedValue, 6)
    }

    /// The deck GROWING moves no card: a longer run moves no item, so the
    /// re-centring belongs to the geometry changing and never to the count.
    func testTheDeckGrowingUnderTheReaderMovesNothing() async throws {
        let renders = Renders()
        let shown = State(0)
        let count = State(4)
        let tree = {
            CarouselView(0..<count.wrappedValue) { Label("\($0)") }
                .position(shown.projectedValue)
                .body
        }

        let showing = measured(renders, tree)
        _ = drainedActs()

        // Laid out, and the opening re-centring answered.
        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: 3 * 312 + 400, height: 300)))
        renders.render(tree())

        let opened = try XCTUnwrap(drainedActs().compactMap(\.completion).first)
        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(opened))
        await settle()

        // The reader stands on card 2 and the deck grows under them.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(2)))
        XCTAssertTrue(renders.fire(rested(showing.first)))

        count.wrappedValue = 6
        renders.render(tree())
        XCTAssertTrue(renders.fire(placer(showing.first).events?[.frameChanged] ?? -1,
                                   with: frame(width: 5 * 312 + 400, height: 300)))
        renders.render(tree())

        XCTAssertEqual(glides(), [], "the deck merely growing pulled the reader's card back")
    }

    /// Taking the swipe away stops the reader's hand, not the carousel: the
    /// scroller stops hearing, and an assigned position still moves it.
    func testTakingTheSwipeAwayStopsTheHandNotTheCarousel() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(3).isSwipeEnabled(false).body })

        XCTAssertEqual(showing.first.props[.inputTransparent], .bool(true))
        XCTAssertEqual(showing.patch.props[.snapInterval], .number(312),
                       "the grid stays - it is the reader who is stopped")
    }

    /// One swipe, one card: the limit rides to the scroller as the most points
    /// of the grid one release may cross.
    func testOneSwipeOneCardReachesTheScroller() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(5).snapsAtMost(1).body })

        XCTAssertEqual(showing.patch.props[.snapsAtMost], .number(1))
    }

    /// The threshold asks for more items as the last card comes up, the
    /// convention every items view here follows.
    func testTheThresholdAsksForMoreNearTheEnd() async {
        let renders = Renders()
        let shown = State(0)
        let asked = State(0)

        let showing = measured(renders, {
            self.carousel(4)
                .position(shown.projectedValue)
                .remainingItemsThreshold(1)
                .onRemainingItemsThresholdReached { asked.wrappedValue += 1 }
                .body
        })

        laid(renders, showing)
        await landing(renders)

        // Card 2 of four: one card from the end, which is the threshold.
        XCTAssertTrue(renders.fire(showing.snap, with: nearest(2)))

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(asked.wrappedValue, 1)
    }
}
