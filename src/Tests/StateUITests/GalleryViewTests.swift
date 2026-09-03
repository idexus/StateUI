// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's own gallery: where a card goes in each of the three shapes,
// how long the run the reader swipes is, and what the one number the scroller
// sends it does.
//
// A GalleryView is made of things that already exist - a ScrollReader over a
// PlacedLayout, with a bus between them - so there is nothing on the C#
// side to check it against and everything worth pinning is here.

import XCTest

@testable import StateUI

final class GalleryViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearBuses()
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
    /// The room the last `laid` laid out in - what `placements` feeds, so a
    /// test that states a room reads the cards that room put there.
    private var room = Rect(0, 0, 352, 400)

    /// Where the clock the engines run on stands, so two turns in one test are
    /// two different instants - a cycle asked for the moment it already
    /// answered is a cycle with nothing to do.
    private var turned = 0.0

    /// The two buses the gallery's layout was described with, remembered from
    /// the FIRST render: a patch carries a property only when it changed, so a
    /// second render says nothing about buses that have not moved.
    private var placer: Int32?
    private var feeder: Int32?

    private func laid(
        _ renders: Renders,
        _ tree: () -> Node,
        width: Double = 352,
        height: Double = 400
    ) -> (patch: Patch, first: Patch) {
        room = Rect(0, 0, width, height)

        let first = renders.render(tree())
        let described = board(first).buses

        placer = described?[.absoluteLayoutBounds]?.bus ?? placer
        feeder = described?[.frame]?.bus ?? feeder

        for id in frames(in: first) {
            XCTAssertTrue(renders.fire(id, with: frame(width: width, height: height)))
        }

        return (renders.render(tree()), first)
    }

    /// The same, described WHOLE - which the fades need: a second render is a
    /// PATCH, and an opacity the room did not change is not in one.
    private func settled(_ tree: () -> Node) -> Patch {
        let renders = Renders()

        _ = laid(renders, tree)

        return renders.renderFromScratch(tree())
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

    /// The run the gallery's engine wrote, driven the way the host drives it:
    /// the room fed onto its bus, one cycle turned, and the placements read
    /// back off the other. NOT ONE OF THEM IS DESCRIBED, so this is where the
    /// numbers a card is drawn at live.
    private func placements(
        _ patch: Patch,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [Placement] {
        let described = board(patch).buses

        guard let fed = described?[.frame]?.bus ?? feeder,
              let run = described?[.absoluteLayoutBounds]?.bus ?? placer
        else {
            XCTFail("the gallery's layout is placed by no bus", file: file, line: line)
            return []
        }

        // THE FIRST CYCLE OF ALL LATCHES rather than runs, so the room is fed
        // after it: a write swallowed by the latch is a write no engine ever
        // sees. Two turns and the arithmetic has answered.
        let board = Renderer.shared.board(for: .vsync)

        _ = board.cycle(now: turned, reducesMotion: false)

        moved(fed, to: [room.x, room.y, room.width, room.height])

        turned += 16
        _ = board.cycle(now: turned, reducesMotion: false)
        turned += 16

        return standing(run, as: PlacedRun.self)?.placements ?? []
    }

    /// Where one card was put.
    private func bounds(_ patch: Patch, _ index: Int) -> PropValue? {
        let run = placements(patch)

        guard index < run.count else { return nil }

        let box = run[index].bounds

        return .numbers([box.x, box.y, box.width, box.height])
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
        let run = placements(patch, file: file, line: line)

        guard index < run.count else {
            XCTFail("card \(index) was drawn at no size", file: file, line: line)
            return 0
        }

        return run[index].transform.height
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

    /// The run is the room plus one card's travel per card past the first, and
    /// it comes to rest on a card.
     /// A gallery told to darken puts most of what a far card wears into the
    /// SHADE and keeps the card nearly opaque - which is the whole point, a
    /// faded card on a wheel showing the card behind it rather than the page.
    func testAShadedGalleryDarkensWhereItWouldHaveFaded() {
        let plain = settled { self.gallery(5).body }

        guard let without = placements(plain).last?.opacity else {
            return XCTFail("a far card said nothing about how opaque it is")
        }

        let shaded = settled {
            self.gallery(5)
                .shade(BoxView(Color("#000000")).cornerRadius(16))
                .body
        }

        guard let with = placements(shaded).last?.opacity else {
            return XCTFail("a far card of a shaded run said nothing")
        }

        XCTAssertLessThan(without, 0.7, "a plain run sends its far cards away by fading")
        XCTAssertGreaterThan(with, without, """
            told to darken, the same card stays far more opaque - the fade \
            drops to a quarter and the shade carries the rest
            """)

        // AND THE SHADE IS A VIEW, wearing the rest of it: the placed node is a
        // grid of two, and the second is what darkens. HOW dark is the
        // placement's, which is why the wrapper says nothing about it.
        let wrapper = board(shaded).children[4]

        XCTAssertEqual(wrapper.type, .grid)
        XCTAssertEqual(wrapper.children.count, 2)
        XCTAssertNil(wrapper.children[1].props[.opacity], "the shade's own fade is the bus's")

        guard let dark = placements(shaded).last?.shade else {
            return XCTFail("the shade said nothing about how dark it is")
        }

        XCTAssertGreaterThan(dark, 0, "a far card wears a shade")
    }

    /// Both strengths are the author's, and nought turns each one off - so a
    /// gallery can darken without fading at all, which is what a run on a dark
    /// page wants.
    func testEachStrengthIsTheAuthorsToTurnDown() {
        func farCard(_ build: (GalleryView<Range<Int>, Int>) -> GalleryView<Range<Int>, Int>)
            -> (opacity: Double, shade: Double) {
            let card = board(settled { build(self.gallery(5)).body }).children[4]

            guard case .number(let opacity)? = card.props[.opacity] else { return (1, 0) }

            guard card.children.count > 1,
                  case .number(let shade)? = card.children[1].props[.opacity]
            else {
                return (opacity, 0)
            }

            return (opacity, shade)
        }

        let mask = BoxView(Color("#000000")).cornerRadius(16)

        let whole = farCard { $0.shade(mask) }
        let half = farCard { $0.shade(mask, amount: 0.5) }
        let none = farCard { $0.shade(mask).fading(0) }

        XCTAssertEqual(half.shade, whole.shade / 2, accuracy: 0.001, """
            the amount says how far the shade goes, and half of it is half as \
            dark
            """)

        XCTAssertEqual(none.opacity, 1, accuracy: 0.001, """
            a gallery told to fade by nought leaves its far cards as opaque as \
            the one in front, whatever else they wear
            """)

        XCTAssertEqual(none.shade, whole.shade, accuracy: 0.001, "and darkens them as before")
    }

    /// A strength outside 0 to 1 is HELD to it rather than refused: a constant
    /// somebody is still tuning is not a reason to take a page down.
    func testAStrengthOutsideTheRangeIsHeldToIt() {
        func shade(of amount: Double) -> Double {
            placements(settled {
                self.gallery(5)
                    .shade(BoxView(Color("#000000")), amount: amount)
                    .body
            }).last?.shade ?? -1
        }

        XCTAssertEqual(shade(of: 4), shade(of: 1), accuracy: 0.001, "above is the whole of it")
        XCTAssertEqual(shade(of: -2), 0, accuracy: 0.001, "and below is none of it")
    }

   func testTheRunIsAsLongAsTheCardsItHas() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(4).body })
        let scroller = try XCTUnwrap(find(.scrollView, in: showing.first))

        // THE RULE RATHER THAN THE NUMBER. How far a hand travels for a card
        // is the only thing that decides how sensitive the run is - what a
        // device sends is a constant, so a longer run is fewer cards a push -
        // and it is a value somebody tunes. What must never drift is that the
        // content and the grid are the SAME number: a run whose length says
        // one distance a card while its grid says another lands off the grid
        // at every card and is dragged back onto it, which a reader sees as a
        // deck that will not sit still.
        let step = try XCTUnwrap(scroller.props[.snapInterval])

        guard case .number(let travel) = step else {
            return XCTFail("the run named no grid")
        }

        XCTAssertGreaterThan(travel, 0, "a run of cards is snapped to its cards")
        XCTAssertEqual(
            find(.boxView, in: showing.patch)?.props[.widthRequest],
            .number(352 + (3 * travel)),
            "the content is the room plus one card's travel per card past the first")

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

        // The event rides the description; WHERE the box stands does not - it
        // follows the offset on the reader's own bus, so it is read off that.
        XCTAssertNotNil(tappable(in: shown.first), "the reader laid no target")

        let box = try XCTUnwrap(tapBox(in: shown.first))

        // The middle card of a wheel is drawn at 1.1, so 176 by 248 becomes
        // 193.6 by 272.8 about the same centre - (88 + 88, 76 + 124).
        for (had, wanted) in zip(
            [box.x, box.y, box.width, box.height], [79.2, 63.6, 193.6, 272.8]
        ) {
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

    /// Where the box that answers a tap stands - which is on the READER's own
    /// bus rather than in the tree: the box follows the offset, and an offset
    /// moves far too often to describe.
    private func tapBox(in patch: Patch) -> Rect? {
        func holder(_ node: Patch) -> Patch? {
            if node.type == .absoluteLayout, tappable(in: node) != nil { return node }

            for child in node.children {
                if let found = holder(child) { return found }
            }

            return nil
        }

        guard let run = holder(patch)?.buses?[.absoluteLayoutBounds]?.bus else { return nil }

        let board = Renderer.shared.board(for: .vsync)

        _ = board.cycle(now: turned, reducesMotion: false)
        turned += 16
        _ = board.cycle(now: turned, reducesMotion: false)
        turned += 16

        // The run's length is the first of the two; the target is the second.
        return standing(run, as: PlacedRun.self)?.placements.last?.bounds
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

    /// The cards are placed by an ENGINE the host turns, so the message names
    /// two buses - the run the placements ride on and the room they are worked
    /// out from - and turning one cycle answers where the cards go.
    func testTheCardsArePlacedByABusTheHostTurns() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).body }).first
        let placer = board(showing)

        XCTAssertEqual(placer.buses?[.absoluteLayoutBounds]?.kind, .placement)
        XCTAssertEqual(placer.buses?[.absoluteLayoutBounds]?.mode, .out)
        XCTAssertEqual(placer.buses?[.frame]?.kind, .feed)

        let run = placements(showing)

        guard run.count == 3 else {
            return XCTFail("the engine placed \(run.count) cards of three")
        }

        XCTAssertEqual(run[0].bounds.x, 88, accuracy: 0.001)
        XCTAssertEqual(run[1].bounds.x, 179.52, accuracy: 0.001)
    }

    /// The shade is a NUMBER to the host, and its ABSENCE is a number too: a
    /// gallery with no shade view answers `unshaded`, which is the one value an
    /// opacity cannot be, and one with a shade answers what the arithmetic
    /// said. Without that the host could not tell a card wearing NONE of a
    /// shade from a run that has no shade at all, both of which say nought.
    func testAGallerySaysWhetherItHasAShadeAtAll() {
        let bare = placements(laid(Renders(), { self.gallery(3).body }).first)

        XCTAssertEqual(bare.first?.shade, PackedPlacement.unshaded, """
            a gallery given no shade view says so on every card, whatever \
            the arithmetic answered
            """)

        let shaded = placements(
            laid(Renders(), { self.gallery(3).shade(BoxView(.black)).body }).first)

        XCTAssertEqual(shaded.first?.shade, 0, "the card in front wears none of it")
        XCTAssertTrue((shaded.last?.shade ?? -1) > 0, "and a card behind it wears some")
    }

    /// A CHANGE OF SHAPE REACHES THE CARDS - end to end, through the bus: the
    /// gallery is told another shape, the deferral writes it down, and what
    /// the engine puts on the bus is where the new shape says the cards go.
    ///
    /// The last reading is taken after a REVISIT, which is the clean walk a
    /// state write really causes. That the shape must be read in the BODY for
    /// any of it to happen is `CycleTests.testAStateOnlyAnEngineReadsArmsNothing`,
    /// which is where that rule is held.
    func testAChangeOfShapeReachesTheCards() {
        let renders = Renders()

        _ = laid(renders, { self.gallery(3).body })

        // The shape is worn a render LATE, so the first of these fires the
        // handler that writes it down and the second is the one that wears it.
        _ = renders.render(self.gallery(3).galleryStyle(.row).body)

        let lined = placements(renders.render(self.gallery(3).galleryStyle(.row).body))

        _ = renders.render(self.gallery(3).galleryStyle(.fan).body)

        let fanned = placements(renders.revisit(changed: Renderer.shared.pendingChanges))

        // THE CARD BEHIND, never the one in front: the front card stands in
        // the middle of the room whatever shape the run is in, and it is where
        // its NEIGHBOURS go that the three shapes disagree about.
        guard let row = lined.last?.bounds, let fan = fanned.last?.bounds else {
            return XCTFail("the gallery placed no cards")
        }

        XCTAssertNotEqual(row, fan, """
            the cards stand where the shape they were last told puts them, \
            and a write only the engine would have read moves nothing
            """)

        // THE DEFERRAL SLEEPS BEFORE IT LETS GO, so it is waited out here
        // rather than left for whichever test runs next: a job still suspended
        // when this returns is a pass another test counts as its own. A
        // suspended sleep is not PENDING until it wakes, so the wait is the
        // crossing's own half-second and a little over it.
        let deadline = Date().addingTimeInterval(0.7)

        while Date() < deadline {
            _ = stateUIRunJobs()
            Thread.sleep(forTimeInterval: 0.02)
        }

        _ = stateUIRunJobs()

        XCTAssertEqual(
            MainThreadExecutor.shared.pendingCount, 0,
            "the shape's deferral was left running")
    }
}
