// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's own gallery: where a card goes in each of the three shapes,
// how long the run the reader swipes is, and what the one number the scroller
// sends it does.
//
// A GalleryView is made of things that already exist - a ScrollReader over a
// PlacedLayout, with a channel between them - so there is nothing on the C#
// side to check it against and everything worth pinning is here.

import XCTest

@testable import StateUI

final class GalleryViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearChannels()
    }

    /// A gallery of numbered cards, each showing its own number.
    private func gallery(_ count: Int) -> GalleryView<Range<Int>, Int> {
        GalleryView(0..<count) { number in
            Label("\(number)")
        }
    }

    /// One frame report: eight numbers, of which these tests use the size.
    private func frame(width: Double, height: Double) -> [PropValue] {
        [.numbers([0, 0, width, height, 0, 0, 0, 0])]
    }

    /// The first node of a kind, however deep it sits.
    private func find(_ type: NodeType, in patch: Patch) -> Patch? {
        if patch.type == type { return patch }

        for child in patch.children {
            if let found = find(type, in: child) { return found }
        }

        return nil
    }

    /// Every frame handler in a tree - a gallery has two readers, one for the
    /// cards and one for the scroller over them.
    private func frames(in patch: Patch) -> [Int] {
        var found: [Int] = []

        func walk(_ node: Patch) {
            if let id = node.events?[.frameChanged] { found.append(id) }
            node.children.forEach(walk)
        }

        walk(patch)

        return found
    }

    /// Renders, tells every reader how big the room is, and renders again -
    /// which is the state a gallery is in the moment it is on screen.
    private func laid(
        _ renders: Renders,
        _ tree: () -> Node,
        width: Double = 352,
        height: Double = 400
    ) -> (patch: Patch, first: Patch) {
        let first = renders.render(tree())

        for id in frames(in: first) {
            XCTAssertTrue(renders.fire(id, with: frame(width: width, height: height)))
        }

        return (renders.render(tree()), first)
    }

    /// Where one card was put, to the nearest thousandth - the arithmetic runs
    /// in radians and fractions, so the numbers do not land on the digit.
    private func assertCard(
        _ patch: Patch,
        _ index: Int,
        _ rect: Rect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .numbers(let put)? = bounds(patch, index) else {
            return XCTFail("card \(index) was placed nowhere", file: file, line: line)
        }

        for (had, wanted) in zip(put, [rect.x, rect.y, rect.width, rect.height]) {
            XCTAssertEqual(had, wanted, accuracy: 0.001, file: file, line: line)
        }
    }

    /// The AbsoluteLayout the cards are placed in.
    private func board(_ patch: Patch) -> Patch {
        find(.absoluteLayout, in: patch) ?? patch
    }

    /// Where one card was put.
    private func bounds(_ patch: Patch, _ index: Int) -> PropValue? {
        board(patch).children[index].props[.absoluteLayoutBounds]
    }

    /// How big one card is DRAWN, against the size it was told - the room's
    /// own answer and the shape's, multiplied together.
    ///
    /// Read off the HEIGHT: a card turned away wears the turn as its `scaleX`,
    /// so that side carries two things at once and this one carries the size
    /// alone.
    private func scale(
        _ patch: Patch,
        _ index: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Double {
        guard case .number(let drawn)? = board(patch).children[index].props[.scaleY] else {
            XCTFail("card \(index) was drawn at no size", file: file, line: line)
            return 0
        }

        return drawn
    }

    // MARK: - The three shapes

    /// The card the run is ON stands in the middle of the room, at the size it
    /// was told, and its neighbours stand out from it.
    func testTheChosenCardStandsInTheMiddle() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).body }).patch

        // 352 wide is room for exactly one card at half of it: 176 by 248 in
        // the middle.
        assertCard(showing, 0, Rect(88, 76, 176, 248))

        // And the next one stands just over half a card out.
        assertCard(showing, 1, Rect(179.52, 76, 176, 248))
    }

    /// A ROW puts them side by side, and no wider than the room however many
    /// there are.
    func testARowPutsTheCardsSideBySide() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).galleryStyle(.row).body }).patch

        assertCard(showing, 0, Rect(88, 76, 176, 248))
        assertCard(showing, 1, Rect(200.64, 76, 176, 248))
    }

    /// A FAN leans them out and sinks them, so the neighbour sits LOWER as
    /// well as to the side.
    func testAFanLeansTheCardsOutAndSinksThem() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).galleryStyle(.fan).body }).patch

        assertCard(showing, 0, Rect(88, 76, 176, 248))
        assertCard(showing, 1, Rect(158.4, 92.12, 176, 248))
    }

    /// A SMALL ROOM shows the same gallery smaller rather than a slice of a
    /// large one: the card is at most half the width and within the height.
    ///
    /// SMALLER IS A SCALE, never a smaller rectangle - which is what takes a
    /// card's own content down with it rather than leaving a caption its own
    /// size in a card too narrow to hold it.
    func testASmallRoomShowsTheSameGallerySmaller() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).body }, width: 264, height: 400).patch

        // The rectangle is the size the card was told, in the middle of the
        // room: 176 by 248 about (132, 200).
        assertCard(showing, 0, Rect(44, 76, 176, 248))

        // And 264 * 0.5 / 176 is three quarters of a card, under the middle
        // card's own 1.1.
        XCTAssertEqual(scale(showing, 0), 1.1 * 0.75, accuracy: 0.001)
    }

    /// AND A LARGE ROOM SHOWS IT LARGER, up to a point. The size a card is
    /// told is the shape of one and the size it stands at in a room exactly
    /// right for it; a bigger room draws a bigger card, by whichever side has
    /// less to give - and never past the ceiling, beyond which the room is
    /// simply room and the run stands in the middle of it.
    func testALargeRoomShowsTheSameGalleryLarger() {
        let renders = Renders()

        // Room for twice a card, so the ceiling is what answers: 242 by 341,
        // in the middle of a thousand by 575.
        let showing = laid(
            renders, { self.gallery(3).body }, width: 1000, height: 575.36).patch

        assertCard(showing, 0, Rect(412, 163.68, 176, 248))
        XCTAssertEqual(scale(showing, 0), 1.1 * 1.375, accuracy: 0.001)
    }

    /// The card's own size is the author's, and everything scales from it.
    func testTheCardsSizeIsTheAuthors() {
        let renders = Renders()
        let showing = laid(
            renders,
            { self.gallery(3).itemSize(width: 100, height: 100).body }).patch

        // Half of 352 is 176, which is 1.76 cards, and 400 within 116 is 3.45
        // - so the ceiling answers, and a 100-square card is drawn at 137.5.
        assertCard(showing, 0, Rect(126, 150, 100, 100))
        XCTAssertEqual(scale(showing, 0), 1.1 * 1.375, accuracy: 0.001)
    }

    // MARK: - What the reader swipes

    /// The run is the room plus half a card per card past the first, and it
    /// comes to rest on a card.
    func testTheRunIsAsLongAsTheCardsItHas() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(4).body })
        let scroller = try XCTUnwrap(find(.scrollView, in: showing.first))

        // 176 wide, so a card is 88 of hand travel: three of them past the
        // first, over a room of 352.
        XCTAssertEqual(
            find(.boxView, in: showing.patch)?.props[.widthRequest], .number(352 + 3 * 88))
        XCTAssertEqual(scroller.props[.snapInterval], .number(88))

        // AND A RUN OF CARDS KEEPS HALF THE PLATFORM'S THROW: a flick
        // meant for a long list carries most of a deck, which is past whatever
        // the reader was aiming at.
        XCTAssertEqual(scroller.props[.scrollMomentum], .number(0.5))
    }

    /// The scroller names the card it is nearest, and that is the position.
    func testTheScrollerWritesTheCardItSettledOn() throws {
        let renders = Renders()
        let shown = State(0)
        let tree = { self.gallery(5).position(shown.projectedValue).body }
        let showing = laid(renders, tree).first

        let scroller = try XCTUnwrap(find(.scrollView, in: showing))
        let report = try XCTUnwrap(scroller.events?[.snapItemChanged])

        XCTAssertTrue(renders.fire(report, with: [.number(3)]))
        XCTAssertEqual(shown.wrappedValue, 3)

        // And a card the run cannot reach is not one it settled on.
        XCTAssertTrue(renders.fire(report, with: [.number(9)]))
        XCTAssertEqual(shown.wrappedValue, 4)
    }

    /// Holding a swipe to one card reaches the scroller.
    func testHoldingASwipeToOneCardReachesTheScroller() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(5).snapsAtMost(1).body }).first

        XCTAssertEqual(find(.scrollView, in: showing)?.props[.snapsAtMost], .number(1))
    }

    /// A tap is answered inside the scroller, which is what lies over the cards
    /// - the only thing here a finger can reach - and ON THE CARD IN FRONT
    /// rather than anywhere along the run.
    ///
    /// The box stands in the CONTENT, where a slot's view sits whatever the
    /// run has been scrolled to, and it is the card as DRAWN: the placement's
    /// rectangle taken through the shape's own scale.
    func testATapIsAnsweredOnTheCardInFront() throws {
        let renders = Renders()
        let shown = laid(renders, { self.gallery(5).onItemTapped { _ in }.body })

        // The event rides the FIRST description; where the box then stands is
        // what the message after the room was reported says.
        let target = try XCTUnwrap(tappable(in: shown.first))
        let placed = try XCTUnwrap(node(target.id, in: shown.patch))

        // The middle card of a wheel is drawn at 1.1, so 176 by 248 becomes
        // 193.6 by 272.8 about the same centre - (88 + 88, 76 + 124).
        guard case .numbers(let box)? = placed.props[.absoluteLayoutBounds] else {
            return XCTFail("the tap was answered nowhere in particular")
        }

        for (had, wanted) in zip(box, [79.2, 63.6, 193.6, 272.8]) {
            XCTAssertEqual(had, wanted, accuracy: 0.001)
        }
    }

    /// And a gallery nobody asked for a tap lays no target at all.
    func testAGalleryNobodyAskedForATapAnswersNone() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(5).body }).first

        XCTAssertNil(tappable(in: showing))
    }

    /// THE CARD IN FRONT ANSWERS THE PRESS. What the reader touches is the
    /// scroller, which lies over every card and takes every touch, so the card
    /// cannot say it was pressed by itself - the gallery says it for it, on the
    /// face inside the placement rather than on the placement, which the host
    /// rewrites on its own frames.
    func testTheCardInFrontIsPressedWhileTheTapIsAnswered() async throws {
        let renders = Renders()
        let view = gallery(5).onItemTapped { _ in }
        let showing = laid(renders, { view.body }).first

        let target = try XCTUnwrap(tappable(in: showing))
        let tap = try XCTUnwrap(target.events?[.tapped])

        XCTAssertTrue(renders.fire(tap))

        XCTAssertEqual(faces(in: renders.render(view.body)).first, .number(0.96))

        // AND IT LETS GO BY ITSELF. Drained to the end rather than left
        // holding: a handler still part-way through is a job queued on this
        // library's executor, and the next test to count what a drain ran
        // would count this one's.
        var back: PropValue?
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline, back == nil {
            stateUIRunJobs()
            try? await Task.sleep(nanoseconds: 5_000_000)
            back = faces(in: renders.render(view.body)).first
        }

        XCTAssertEqual(back, .number(1))
    }

    /// One element of a message, by the identity it was given.
    private func node(_ id: ElementId, in patch: Patch) -> Patch? {
        if patch.id == id { return patch }

        for child in patch.children {
            if let found = node(id, in: child) { return found }
        }

        return nil
    }

    /// The box a tap is answered on, if the gallery laid one.
    private func tappable(in patch: Patch) -> Patch? {
        func walk(_ node: Patch) -> Patch? {
            if node.type == .boxView, node.events?[.tapped] != nil { return node }

            for child in node.children {
                if let found = walk(child) { return found }
            }

            return nil
        }

        return walk(patch)
    }

    /// How big each card's FACE is drawn inside its placement - the press, and
    /// nothing else, since the placement itself is written a level above.
    private func faces(in patch: Patch) -> [PropValue] {
        var found: [PropValue] = []

        func walk(_ node: Patch) {
            if node.type == .label, let scale = node.props[.scale] { found.append(scale) }

            node.children.forEach(walk)
        }

        walk(patch)

        return found
    }

    /// A gallery nobody may swipe lays no scroller over the cards at all: the
    /// reader's hand is stopped, and there is nothing left to stop it with.
    func testAGalleryNobodyMaySwipeLaysNoScroller() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).isSwipeEnabled(false).body }).first

        XCTAssertNil(find(.scrollView, in: showing))
        XCTAssertNotNil(find(.absoluteLayout, in: showing))
    }

    /// And one with nothing to show shows what it was given instead.
    func testAnEmptyGalleryShowsWhatItWasGiven() {
        let renders = Renders()
        let patch = renders.render(
            GalleryView([Int]()) { number in Label("\(number)") }
                .emptyView(Label("nothing here"))
                .body)

        XCTAssertNil(find(.absoluteLayout, in: patch))
        XCTAssertEqual(find(.label, in: patch)?.props[.text], .string("nothing here"))
    }

    // MARK: - What the host is told

    /// The cards are placed by a rule the HOST runs, so the message carries a
    /// channel and the id of the arithmetic - and running that arithmetic
    /// answers the same places the render described.
    func testTheCardsFollowAChannelTheHostMoves() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).body }).first
        let placer = board(showing)

        XCTAssertEqual(placer.props[.channels], .numbers([1]))

        let rule = try XCTUnwrap(placer.props[.channelRule]?.number)
        let arithmetic = try XCTUnwrap(renders.placement(Int(rule)))

        XCTAssertEqual(arithmetic(0, 3, Rect(0, 0, 352, 400)).bounds.x, 88, accuracy: 0.001)
        XCTAssertEqual(arithmetic(1, 3, Rect(0, 0, 352, 400)).bounds.x, 179.52, accuracy: 0.001)
    }
}
