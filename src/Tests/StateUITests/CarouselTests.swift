// The library's own carousel: what it places, what it describes, and when it
// takes the offset over.
//
// A CarouselView is made of controls that already exist - a ScrollView, an
// AbsoluteLayout, the cards - so there is nothing on the C# side to check it
// against, and everything worth pinning is on this side: how a card is cut
// from the visible area, which cards are described at all, and what each
// moment of the reader's touch makes it do.

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
    ) -> (patch: Patch, first: Patch, scroll: Int, gesture: Int) {
        let first = renders.render(tree())
        let scroll = first.events?[.scrollXChanged] ?? first.events?[.scrollYChanged] ?? -1
        let gesture = first.events?[.scrollGesture] ?? -1

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1,
                                   with: frame(width: width, height: height)))

        return (renders.render(tree()), first, scroll, gesture)
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
        let showing = measured(renders, { self.carousel(4).itemFraction(0.5).spacing(20).body })

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

    /// Only the card the OFFSET is over and its neighbours are described - the
    /// rest of a long deck is not built and not sent.
    func testOnlyTheCardInViewAndItsNeighboursAreDescribed() {
        let renders = Renders()
        let shown = State(7)
        let tree = { self.carousel(40).position(shown.projectedValue).body }
        let showing = measured(renders, tree)

        // Scrolled to card 7, which is where the position says it is.
        XCTAssertTrue(renders.fire(showing.scroll, with: [.number(7 * 312)]))

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

    /// One report of the reader's touch: the phase, the offset, and where the
    /// platform would leave it - sideways, which is the axis these read.
    private func touch(_ phase: ScrollGesturePhase, at offset: Double, predicted: Double? = nil) -> [PropValue] {
        [.enumeration(phase.rawValue), .numbers([offset, 0]), .numbers([predicted ?? offset, 0])]
    }

    /// The scroll acts queued, as the offset each asked for along the axis.
    private func glides() -> [Double] {
        drainedActs().filter { $0.name == "scrollToAsync" }.compactMap { $0.arguments[1].number }
    }

    /// The carousel tells the scroller to rest on multiples of a SLOT, which
    /// is what makes the platform's own deceleration end on a card - and it
    /// hears the offset once per card rather than once per frame.
    func testTheSlotIsTheSnapIntervalAndTheReportStep() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(5).body })

        XCTAssertEqual(showing.patch.props[.snapInterval], .number(312))
        XCTAssertEqual(showing.patch.props[.scrollStep], .number(312))
    }

    /// A lifted finger writes the position AT ONCE, from where the platform
    /// says it is going - so the dots move with the movement rather than when
    /// it arrives. Nothing is asked of the scroller: it is already on its way.
    func testALiftedFingerWritesWhereThePlatformIsGoing() {
        let renders = Renders()
        let shown = State(0)
        let showing = measured(renders, { self.carousel(5).position(shown.projectedValue).body })
        _ = drainedActs()

        // The lift is at 300 and the platform is braking to 624 - card 2's
        // middle, which is where it was told to stop.
        XCTAssertTrue(renders.fire(showing.gesture, with: touch(.touchUp, at: 300, predicted: 624)))

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(glides(), [], "the carousel asked for a movement the platform was already making")
    }

    /// There is no cap: a throw the platform carries three cards is three
    /// cards, and the window is on the destination before the glide arrives.
    func testAThrowIsFollowedWhereverThePlatformCarriesIt() {
        let renders = Renders()
        let shown = State(0)
        let tree = { self.carousel(9).position(shown.projectedValue).body }
        let showing = measured(renders, tree)

        XCTAssertTrue(renders.fire(showing.gesture, with: touch(.touchUp, at: 100, predicted: 3 * 312)))

        XCTAssertEqual(shown.wrappedValue, 3)
        XCTAssertEqual(self.shown(renders.render(tree())), ["1", "2", "3", "4", "5"],
                       "the cards it is flying to were described when it set off")
    }

    /// A rest ON a card is the platform having landed where it was sent:
    /// the position is confirmed and nothing moves.
    func testARestOnACardAsksForNothing() {
        let renders = Renders()
        let shown = State(0)
        let showing = measured(renders, { self.carousel(5).position(shown.projectedValue).body })
        _ = drainedActs()

        XCTAssertTrue(renders.fire(showing.gesture, with: touch(.stopped, at: 624)))

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(glides(), [])
    }

    /// And a rest BETWEEN two cards is a scroller the snap interval did not
    /// reach, so the carousel takes it to the card itself.
    func testARestBetweenCardsIsLandedByHand() {
        let renders = Renders()
        let shown = State(0)
        let showing = measured(renders, { self.carousel(5).position(shown.projectedValue).body })
        _ = drainedActs()

        XCTAssertTrue(renders.fire(showing.gesture, with: touch(.stopped, at: 500)))

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(glides(), [624])
    }

    /// While the reader's finger has the offset, an assigned position does
    /// not move it - the assignment waits for the finger to lift.
    func testAFingerDownKeepsAnAssignedPositionFromGliding() {
        let renders = Renders()
        let shown = State(0)
        let tree = { self.carousel(5).position(shown.projectedValue).body }
        let showing = measured(renders, tree)
        _ = drainedActs()

        XCTAssertTrue(renders.fire(showing.gesture, with: touch(.touchDown, at: 100)))

        shown.wrappedValue = 3
        renders.render(tree())

        XCTAssertEqual(glides(), [], "the carousel moved the offset under the reader's finger")
    }

    /// The threshold asks for more items as the last card comes up, the
    /// convention every items view here follows.
    func testTheThresholdAsksForMoreNearTheEnd() {
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

        // Card 2 of four: one card from the end, which is the threshold.
        XCTAssertTrue(renders.fire(showing.gesture, with: touch(.stopped, at: 624)))

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(asked.wrappedValue, 1)
    }
}
