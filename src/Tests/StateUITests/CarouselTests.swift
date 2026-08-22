// The library's own carousel: what it places, what it describes, and when it
// takes the offset over.
//
// A CarouselView is made of controls that already exist - a ScrollView, an
// AbsoluteLayout, the cards - so there is nothing on the C# side to check it
// against, and everything worth pinning is on this side: how a card is cut
// from the visible area, which cards are described at all, and the two things
// that have to be true before a settle runs.

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
    ) -> (patch: Patch, first: Patch, scroll: Int) {
        let first = renders.render(tree())
        let scroll = first.events?[.scrollXChanged] ?? first.events?[.scrollYChanged] ?? -1

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1,
                                   with: frame(width: width, height: height)))

        return (renders.render(tree()), first, scroll)
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

    /// Only the middle card and its neighbours are described - the rest of a
    /// long deck is not built and not sent.
    func testOnlyTheMiddleCardAndItsNeighboursAreDescribed() {
        let renders = Renders()
        let shown = State(7)
        let showing = measured(renders, { self.carousel(40).position(shown.projectedValue).body })

        XCTAssertEqual(self.shown(showing.patch), ["6", "7", "8"])
    }

    /// And at an end there is no neighbour to describe.
    func testAnEndHasOneNeighbour() {
        let renders = Renders()
        let showing = measured(renders, { self.carousel(40).body })

        XCTAssertEqual(self.shown(showing.patch), ["0", "1"])
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

    /// An offset that has stopped settles on the card nearest it, and the
    /// POSITION is what the settle writes.
    func testASettleWritesTheNearestCard() async {
        let renders = Renders()
        let shown = State(0)
        let showing = measured(renders, { self.carousel(5).position(shown.projectedValue).body })

        // The pads make an offset one slot per card, so card 2 is centred at
        // 624. This is a drag that stopped just short of it.
        XCTAssertTrue(renders.fire(showing.scroll, with: [.number(610)]))
        await settled()

        XCTAssertEqual(shown.wrappedValue, 2)
    }

    /// A report CANCELS the settle the report before it armed, which is what
    /// keeps the carousel off a movement that is still going: a fling arms one
    /// settle per frame and runs the last of them.
    func testAReportCancelsTheSettleTheOneBeforeItArmed() async {
        let renders = Renders()
        let shown = State(0)
        let landings = State(0)

        let showing = measured(renders, {
            self.carousel(5)
                .position(shown.projectedValue)
                .onPositionChanged { _ in landings.wrappedValue += 1 }
                .body
        })

        // Card 1's centre, then card 2's, with no quiet in between.
        XCTAssertTrue(renders.fire(showing.scroll, with: [.number(312)]))
        XCTAssertTrue(renders.fire(showing.scroll, with: [.number(624)]))
        await settled()

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(landings.wrappedValue, 1, "the settle armed first ran as well")
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

        // Card 2 of four: one card from the end, which is the threshold.
        XCTAssertTrue(renders.fire(showing.scroll, with: [.number(624)]))
        await settled()

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(asked.wrappedValue, 1)
    }

    /// Everything a settle does happens after the quiet a lifted finger
    /// leaves, so a test waits for it the way the carousel does.
    private func settled() async {
        for _ in 0..<40 {
            _ = stateUIRunJobs()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
