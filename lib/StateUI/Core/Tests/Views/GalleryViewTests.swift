// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's own gallery: where a card goes in each of the three shapes,
// how long the run the user swipes is, and what the one number the scroller
// sends it does.
//
// A GalleryView is a PhaseLayout with the arithmetic of three shapes
// written, so there is nothing in a host to check it against and everything
// worth pinning is here.

import XCTest

@_spi(Host) @testable import StateUI

/// How many cards were described - a class, so the closure that counts into it
/// is not walked for state.
private final class Built {
    var count = 0
}

@MainActor
final class GalleryViewTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// A gallery of numbered cards, each showing its own number.
    private func gallery(_ count: Int) -> GalleryView<Range<Int>, Int> {
        GalleryView(0..<count) { number in
            Text("\(number)")
        }
    }

    /// One frame report: eight numbers, of which these tests use the size.
    private func frame(width: Double, height: Double) -> [PropValue] {
        [.numbers([0, 0, width, height, 0, 0, 0, 0])]
    }

    /// The first node of a kind, however deep it sits.
    private func find(_ type: NodeType, in patch: HostPatch) -> HostPatch? {
        if patch.type == type { return patch }

        for child in patch.children {
            if let found = find(type, in: child) { return found }
        }

        return nil
    }

    /// Every frame handler in a tree - a gallery has two readers, one for the
    /// cards and one for the scroller over them.
    private func frames(in patch: HostPatch) -> [Int] {
        var found: [Int] = []

        func walk(_ node: HostPatch) {
            if let id = node.events?[.frameChanged] { found.append(id) }
            node.children.forEach(walk)
        }

        walk(patch)

        return found
    }

    /// The room the last `laid` laid out in - what `placements` feeds, so a
    /// test that states a room reads the cards that room put there.
    private var room = Rect(0, 0, 352, 400)

    /// Where the clock the engines run on stands, so two turns in one test are
    /// two different instants - a cycle asked for the moment it already
    /// answered is a cycle with nothing to do.
    private var turned = 0.0

    /// The two states the gallery's layout was described with, remembered from
    /// the FIRST render: a patch carries a property only when it changed, so a
    /// second render says nothing about states that have not moved.
    private var placer: Int32?
    private var feeder: Int32?

    /// Renders, tells every reader how big the room is, and renders again -
    /// until no reader stands that has not been told, as the run of cards
    /// stands only once its reader knows its room - which is the state a
    /// gallery is in the moment it is on screen: the last patch, and the whole
    /// gallery described as it then stands.
    private func laid(
        _ renders: Renders,
        _ tree: () -> Node,
        width: Double = 352,
        height: Double = 400
    ) -> (patch: HostPatch, whole: HostPatch) {
        room = Rect(0, 0, width, height)

        let first = renders.render(tree())
        let described = board(first).driven

        placer = described?[.area]?.state ?? placer
        feeder = described?[.frame]?.state ?? feeder

        var told: Set<Int> = []
        var patch = first
        for _ in 0..<3 {
            let untold = frames(in: patch).filter { !told.contains($0) }
            guard !untold.isEmpty else { break }
            for id in untold {
                XCTAssertTrue(renders.fire(id, with: frame(width: width, height: height)))
                told.insert(id)
            }
            patch = renders.render(tree())
            let described = board(patch).driven
            placer = described?[.area]?.state ?? placer
            feeder = described?[.frame]?.state ?? feeder
        }

        // The run told its room as well, as the host tells it: the hand is measured against the cards it draws.
        if let feeder {
            turned += 16
            _ = HostBoundary.cycle(now: turned, reducesMotion: false)
            moved(feeder, to: [0, 0, width, height])
            turned += 16
            _ = HostBoundary.cycle(now: turned, reducesMotion: false)
        }

        return (patch, renders.renderFromScratch(tree()))
    }

    /// The same, described WHOLE - which the fades need: a second render is a
    /// PATCH, and an opacity the room did not change is not in one.
    private func settled(_ tree: () -> Node) -> HostPatch {
        let renders = Renders()

        _ = laid(renders, tree)

        return renders.renderFromScratch(tree())
    }

    /// Where one card was put, to the nearest thousandth - the arithmetic runs
    /// in radians and fractions, so the numbers do not land on the digit.
    private func assertCard(
        _ patch: HostPatch,
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

    /// The layout the cards are placed in.
    private func board(_ patch: HostPatch) -> HostPatch {
        find(.phaseLayout, in: patch) ?? patch
    }

    /// The run the gallery's engine wrote, driven the way the host drives it:
    /// the room fed onto its number, one cycle turned, and the placements read
    /// back off the other. NOT ONE OF THEM IS DESCRIBED, so this is where the
    /// numbers a card is drawn at live.
    private func placements(
        _ patch: HostPatch,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [Placement] {
        let described = board(patch).driven

        guard let fed = described?[.frame]?.state ?? feeder,
              let run = described?[.area]?.state ?? placer
        else {
            XCTFail("the gallery's layout is placed by no number", file: file, line: line)
            return []
        }

        // THE FIRST CYCLE OF ALL LATCHES rather than runs, so the room is fed
        // after it: a write swallowed by the latch is a write no engine ever
        // sees. Two turns and the arithmetic has answered.
        let board = Renderer.shared.board

        _ = board.cycle(now: turned, reducesMotion: false)

        moved(fed, to: [room.x, room.y, room.width, room.height])

        turned += 16
        _ = board.cycle(now: turned, reducesMotion: false)
        turned += 16

        return standing(run, as: PlacedRun.self)?.placements ?? []
    }

    /// Where one card was put.
    private func bounds(_ patch: HostPatch, _ index: Int) -> PropValue? {
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
        _ patch: HostPatch,
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

    /// A CHANGE OF POSITION DOES NOT DESCRIBE THE CARDS.
    ///
    /// Where each card GOES is the engine's, worked out from the offset on the
    /// host's own frames, so nothing about a card's picture follows the run
    /// being turned. The gallery does read the position - a watcher compares
    /// the value it was described with - but it reads it in a view of its OWN,
    /// beside the deck rather than above it, which is the whole of why a card
    /// crossed leaves the deck standing.
    ///
    /// THE MESSAGE CANNOT SAY THIS: the differ finds the cards unchanged and
    /// sends nothing either way, so what is counted here is the DESCRIBING.
    /// It is what the round of 2026-09-10 was chasing - a card crossed
    /// re-described the whole deck, the message re-measured the page, and on a
    /// Mac a measure invalidates UIKit's focus, whose walk over the view tree
    /// then holds the thread for ~90 ms. notes/driven-state.md.
    func testAChangeOfPositionDoesNotDescribeTheCards() {
        let renders = Renders()
        let standing = State(0)
        let built = Built()

        func tree() -> Node {
            GalleryView(0..<6) { number in
                built.count += 1
                return Text("\(number)")
            }
            .position(standing.projectedValue)
            .node
        }

        _ = laid(renders, tree)

        let made = built.count
        XCTAssertGreaterThan(made, 0, "no card was described at all")

        Renderer.shared.clearInvalidation()
        standing.wrappedValue = 1

        // THE CLEAN WALK, which is what a write that names itself gets: only
        // the elements whose reads intersect the change are built again. A
        // whole-tree render describes everything by construction and could
        // never tell this apart.
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(built.count, made, """
            The cards were described again for a position none of them shows.
            """)
    }

    /// A FRAME OF THE HAND RENDERS NOBODY: the hand moves the run on the host's
    /// own frames, and the only thing a body is built for is the card in FRONT
    /// changing - once per card, never once per frame.
    func testAFrameOfTheHandRendersNobody() {
        let renders = Renders()
        func tree() -> Node { gallery(6).node }
        _ = laid(renders, tree)

        hand(renders, tree, .began)
        Renderer.shared.clearInvalidation()

        // Ten moves within the card in front, a few points each.
        for step in 1...10 {
            hand(renders, tree, .changed, moved: Point(-4, 0))

            XCTAssertFalse(Renderer.shared.needsRender, "move \(step) of the hand asked for a render")
        }
    }

    /// THE CARDS STAND IN READING ORDER, as a stack's views do: the gallery's
    /// layout mirrors right to left.
    func testTheCardsStandInReadingOrder() throws {
        let patch = Renders().render(gallery(3).node)

        XCTAssertEqual(try XCTUnwrap(patch.first(.phaseLayout)).props[.mirrorsRightToLeft], .bool(true))
    }

    /// The card the run is ON stands in the middle of the room, at the size it
    /// was told, and its neighbors stand out from it.
    func testTheChosenCardStandsInTheMiddle() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).node }).patch

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
        let showing = laid(renders, { self.gallery(3).arrangement(.row).node }).patch

        assertCard(showing, 0, Rect(88, 76, 176, 248))
        assertCard(showing, 1, Rect(200.64, 76, 176, 248))
    }

    /// A FAN leans them out and sinks them, so the neighbor sits LOWER as
    /// well as to the side.
    func testAFanLeansTheCardsOutAndSinksThem() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).arrangement(.fan).node }).patch

        assertCard(showing, 0, Rect(88, 76, 176, 248))
        assertCard(showing, 1, Rect(158.4, 92.12, 176, 248))
    }

    /// A DECK stands the cards one behind another: the card in front whole and
    /// straight in the middle, the next a few points out to the side and down,
    /// smaller and turned a little.
    func testADeckStandsTheCardsOneBehindAnother() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).arrangement(.deck).node }).patch

        assertCard(showing, 0, Rect(88, 76, 176, 248))
        assertCard(showing, 1, Rect(102, 79, 176, 248))
    }

    /// A DECK IS SWIPED A CARD AT A TIME, however far the hand goes.
    func testADeckIsSwipedACardAtATime() {
        let renders = Renders()
        let shown = State(0)
        func tree() -> Node { gallery(5).arrangement(.deck).position(shown.projectedValue).node }
        _ = laid(renders, tree)

        hand(renders, tree, .began)
        hand(renders, tree, .changed, moved: Point(-20 * reach, 0))
        XCTAssertEqual(shown.wrappedValue, 1, "one card, not the last")
    }

    /// A SMALL ROOM shows the same gallery smaller rather than a slice of a
    /// large one: the card is at most half the width and within the height.
    ///
    /// SMALLER IS A SCALE, never a smaller rectangle - which is what takes a
    /// card's own content down with it rather than leaving a caption its own
    /// size in a card too narrow to hold it.
    func testASmallRoomShowsTheSameGallerySmaller() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).node }, width: 264, height: 400).patch

        // The rectangle is the size the card was told, in the middle of the
        // room: 176 by 248 about (132, 200).
        assertCard(showing, 0, Rect(44, 76, 176, 248))

        // And 264 * 0.5 / 176 is three quarters of a card, under the middle
        // card's own 1.1.
        XCTAssertEqual(scale(showing, 0), 1.1 * 0.75, accuracy: 0.001)
    }

    /// A CARD STANDS AT ITS STATED SIZE before the run places it. A card the
    /// run has not placed yet is laid out as it is - and one with no size of
    /// its own would fill the whole room, its pictures drawn that large.
    func testACardStandsAtItsStatedSizeBeforeTheRunPlacesIt() {
        // Each card in the wrapper the run places, the card's own inside it.
        let cards = board(Renders().render(gallery(3).node)).children.compactMap(\.children.first)

        XCTAssertEqual(cards.count, 3)
        for card in cards {
            XCTAssertEqual(card.properties[.width], .number(176))
            XCTAssertEqual(card.properties[.height], .number(248))
        }
    }

    /// A ROOM NOT YET MEASURED PLACES NO CARD: until the platform says how big
    /// the room is, every card stands as it is, never drawn at a scale worked
    /// out from nothing.
    func testARoomNotYetMeasuredPlacesNoCard() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).node }, width: 0, height: 0).patch

        XCTAssertEqual(placements(showing).count, 0)
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
            renders, { self.gallery(3).node }, width: 1000, height: 575.36).patch

        assertCard(showing, 0, Rect(412, 163.68, 176, 248))
        XCTAssertEqual(scale(showing, 0), 1.1 * 1.375, accuracy: 0.001)
    }

    /// The card's own size is the author's, and everything scales from it.
    func testTheCardsSizeIsTheAuthors() {
        let renders = Renders()
        let showing = laid(
            renders,
            { self.gallery(3).itemSize(width: 100, height: 100).node }).patch

        // Half of 352 is 176, which is 1.76 cards, and 400 within 116 is 3.45
        // - so the ceiling answers, and a 100-square card is drawn at 137.5.
        assertCard(showing, 0, Rect(126, 150, 100, 100))
        XCTAssertEqual(scale(showing, 0), 1.1 * 1.375, accuracy: 0.001)
    }

    // MARK: - What the user swipes

    /// A gallery told to darken puts most of what a far card wears into the
    /// SHADE and keeps the card nearly opaque - which is the whole point, a
    /// faded card on a wheel showing the card behind it rather than the page.
    func testAShadedGalleryDarkensWhereItWouldHaveFaded() {
        let plain = settled { self.gallery(5).node }

        guard let without = placements(plain).card(4)?.opacity else {
            return XCTFail("a far card said nothing about how opaque it is")
        }

        let shaded = settled {
            self.gallery(5)
                .shade(
                    Rectangle()
                        .fill(Color(hex: 0x000000))
                        .cornerRadius(16))
                .node
        }

        guard let with = placements(shaded).card(4)?.opacity else {
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
        XCTAssertNil(wrapper.children[1].props[.opacity], "the shade's own fade is the number's")

        guard let dark = placements(shaded).card(4)?.shade else {
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
            let card = board(settled { build(self.gallery(5)).node }).children[4]

            guard case .number(let opacity)? = card.props[.opacity] else { return (1, 0) }

            guard card.children.count > 1,
                  case .number(let shade)? = card.children[1].props[.opacity]
            else {
                return (opacity, 0)
            }

            return (opacity, shade)
        }

        let mask = Rectangle()
            .fill(Color(hex: 0x000000))
            .cornerRadius(16)

        let whole = farCard { $0.shade(mask) }
        let half = farCard { $0.shade(mask, amount: 0.5) }
        let none = farCard { $0.shade(mask).fade(0) }

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
                    .shade(
                        Rectangle()
                            .fill(Color(hex: 0x000000)),
                        amount: amount)
                    .node
            }).card(4)?.shade ?? -1
        }

        XCTAssertEqual(shade(of: 4), shade(of: 1), accuracy: 0.001, "above is the whole of it")
        XCTAssertEqual(shade(of: -2), 0, accuracy: 0.001, "and below is none of it")
    }

    /// How far the hand travels for one card: as far as the card in front goes on the wheel, at its stated size.
    private let reach = 176.0 * 0.52

    /// The hand over the gallery `tree` describes, as a host reports it, and a cycle after it.
    private func hand(
        _ renders: Renders, _ tree: () -> Node, _ phase: GesturePhase, moved: Point = .zero, speed: Point = .zero
    ) {
        guard let heard = find(.phaseLayout, in: renders.renderFromScratch(tree()))?.events?[.handMoved] else {
            return XCTFail("the gallery hears no hand")
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(phase, moved, speed)))
        turned += 16
        _ = HostBoundary.cycle(now: turned, reducesMotion: false)
    }

    /// The hand NAMES the card it passes: as it crosses halfway between two
    /// cards the position is the nearer one, a move between two names nothing
    /// new, and a card the run cannot reach is not one it names.
    func testTheHandNamesTheCardItPasses() throws {
        let renders = Renders()
        let shown = State(0)
        func tree() -> Node { gallery(5).position(shown.projectedValue).node }
        _ = laid(renders, tree)

        hand(renders, tree, .began)
        hand(renders, tree, .changed, moved: Point(-2.6 * reach, 0))
        XCTAssertEqual(shown.wrappedValue, 3)

        hand(renders, tree, .changed, moved: Point(-0.3 * reach, 0))
        XCTAssertEqual(shown.wrappedValue, 3, "a move between two cards names nothing new")

        hand(renders, tree, .changed, moved: Point(2.5 * reach, 0))
        XCTAssertEqual(shown.wrappedValue, 0)

        hand(renders, tree, .changed, moved: Point(-20 * reach, 0))
        XCTAssertEqual(shown.wrappedValue, 4, "a card past the last is the last")
    }

    /// A ROOM THAT GROWS KEEPS THE CARD IN FRONT: the run stands on the
    /// phase, which a room does not move - a phone turned shows the card the
    /// user left there.
    func testARoomThatGrowsKeepsTheCardInFront() throws {
        let renders = Renders()
        let shown = State(0)
        func tree() -> Node { gallery(5).position(shown.projectedValue).node }
        let showing = laid(renders, tree)
        let phase = try XCTUnwrap(find(.phaseLayout, in: showing.whole)?.driven?[.phase]?.state)

        hand(renders, tree, .began)
        hand(renders, tree, .changed, moved: Point(-4 * reach, 0))
        hand(renders, tree, .ended)
        XCTAssertEqual(shown.wrappedValue, 4)

        if let feeder { moved(feeder, to: [0, 0, 700, 300]) }
        turned += 16
        _ = HostBoundary.cycle(now: turned, reducesMotion: false)

        XCTAssertEqual(shown.wrappedValue, 4, "the card the user left in front")
        XCTAssertEqual(try XCTUnwrap(standing(phase, as: JourneyLanes<Double>.self)).destination, 4)
    }

    /// A RUN SENT TO A CARD NAMES NONE ON THE WAY: the position written, the
    /// run travels there, and every card it passes is behind or ahead of the
    /// one it goes to - naming it would turn the position back and forth.
    func testARunSentToACardNamesNoneOnTheWay() async throws {
        let renders = Renders()
        let shown = State(1)
        var heard: [Int] = []
        func tree() -> Node {
            gallery(5).position(shown.projectedValue).onPositionChanged { heard.append($0) }.node
        }
        let showing = laid(renders, tree)
        let board = Renderer.shared.board

        shown.wrappedValue = 3
        _ = renders.render(tree())
        _ = await settle()

        // The host walks the phase from card 1 towards card 3: a frame of the way.
        let phase = try XCTUnwrap(find(.phaseLayout, in: showing.whole)?.driven?[.phase]?.state)
        moved(phase, to: 1.4)
        turned += 16
        _ = board.cycle(now: turned, reducesMotion: false)

        XCTAssertEqual(shown.wrappedValue, 3, "the card it goes to, not the one it passes")
        XCTAssertEqual(heard, [3], "the author hears the position once")
    }

    /// A run LET GO between two cards comes onto the nearer, named at once.
    /// A run let go on a card is left there.
    func testARunLetGoBetweenTwoCardsTravelsOnToTheNearer() throws {
        let renders = Renders()
        func tree() -> Node { gallery(5).node }
        let showing = laid(renders, tree)
        let phase = try XCTUnwrap(find(.phaseLayout, in: showing.whole)?.driven?[.phase]?.state)

        hand(renders, tree, .began)
        hand(renders, tree, .changed, moved: Point(-1.4 * reach, 0))
        hand(renders, tree, .ended)

        let sent = try XCTUnwrap(standing(phase, as: JourneyLanes<Double>.self))
        XCTAssertEqual(sent.destination, 1, accuracy: 0.001, "the nearer card")

        // The run comes onto it, and the hand lets go of it on the card.
        for _ in 0..<30 {
            turned += 16
            _ = HostBoundary.cycle(now: turned, reducesMotion: false)
        }
        hand(renders, tree, .began)
        hand(renders, tree, .ended)

        let left = try XCTUnwrap(standing(phase, as: JourneyLanes<Double>.self))
        XCTAssertEqual(left.destination, 1, accuracy: 0.001, "a run on a card stays")
        XCTAssertEqual(left.value, 1, accuracy: 0.001)
    }

    /// A THROW GOES ON AS `.throwing` SAYS: the same swipe let go with speed,
    /// carried for three seconds' worth, comes to rest two cards on, where
    /// the light friction of a gallery that says nothing slides it back to the
    /// first.
    func testAThrowGoesOnAsThrowingSays() {
        for (throwing, card) in [(Motion?.none, 0), (.eased(.seconds(3), .cubicOut), 2)] {
            Renderer.shared.clearStates()
            let renders = Renders()
            let shown = State(0)
            func tree() -> Node {
                let swiped = gallery(5).position(shown.projectedValue)
                return (throwing.map { swiped.throwing($0) } ?? swiped).node
            }
            _ = laid(renders, tree)

            hand(renders, tree, .began)
            hand(renders, tree, .changed, moved: Point(-0.1 * reach, 0))
            hand(renders, tree, .ended, speed: Point(-200, 0))

            XCTAssertEqual(shown.wrappedValue, card, "thrown \(throwing.map { "\($0.kind)" } ?? "as a gallery is")")
        }
    }

    /// A tap ACTIVATES THE CARD IN FRONT, on the card itself, rather than
    /// anywhere along the run: a card behind it hears the tap and does nothing,
    /// and the card in front is handed over by its identity.
    func testATapActivatesTheCardInFront() async throws {
        var heard: [Int] = []
        let renders = Renders()
        let shown = laid(renders, { self.gallery(5).onItemActivated { heard.append($0) }.node })
        let cards = try XCTUnwrap(find(.phaseLayout, in: shown.whole)).children.compactMap { $0.events?[.tapped] }

        XCTAssertEqual(cards.count, 5, "every card hears a tap")

        XCTAssertTrue(renders.fire(cards[1]))
        XCTAssertTrue(renders.fire(cards[0]))
        for _ in 0..<100 {
            guard heard.isEmpty else { break }
            stateUIRunJobs()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertEqual(heard, [0], "the card in front alone")
    }

    /// And a gallery nobody asked for a tap lays no target at all.
    /// A gallery the user may not swipe still answers a tap on the card in front: nothing scrolls, so the
    /// target stands where the card does.
    func testAGalleryNobodyMaySwipeAnswersATapOnItsCardInFront() throws {
        let renders = Renders()
        let shown = laid(renders, { self.gallery(5).isSwipeEnabled(false).onItemActivated { _ in }.node })

        XCTAssertNotNil(tappable(in: shown.whole), "the gallery laid no target")
    }

    func testAGalleryNobodyAskedForATapAnswersNone() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(5).node }).whole

        XCTAssertNil(tappable(in: showing))
    }

    /// THE CARD IN FRONT ANSWERS THE PRESS. What the user touches is the
    /// scroller, which lies over every card and takes every touch, so the card
    /// cannot say it was pressed by itself - the gallery says it for it, on the
    /// face inside the placement rather than on the placement, which the host
    /// rewrites on its own frames.
    @MainActor
    func testTheCardInFrontIsPressedWhileTheTapIsAnswered() async throws {
        let renders = Renders()
        let view = gallery(5).onItemActivated { _ in }
        let showing = laid(renders, { view.node }).whole

        let target = try XCTUnwrap(tappable(in: showing))
        let tap = try XCTUnwrap(target.events?[.tapped])

        XCTAssertTrue(renders.fire(tap))

        XCTAssertEqual(faces(in: renders.render(view.node)).first, .number(0.96))

        // AND IT LETS GO BY ITSELF. Drained to the end rather than left
        // holding: a handler still part-way through is a job queued on this
        // library's executor, and the next test to count what a drain ran
        // would count this one's.
        var back: PropValue?
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline, back == nil {
            stateUIRunJobs()
            try? await Task.sleep(nanoseconds: 5_000_000)
            back = faces(in: renders.render(view.node)).first
        }

        XCTAssertEqual(back, .number(1))
    }

    /// One element of a message, by the identity it was given.
    private func node(_ id: ElementID, in patch: HostPatch) -> HostPatch? {
        if patch.id == id { return patch }

        for child in patch.children {
            if let found = node(id, in: child) { return found }
        }

        return nil
    }

    /// The box a tap is answered on, if the gallery laid one.
    private func tappable(in patch: HostPatch) -> HostPatch? {
        func walk(_ node: HostPatch) -> HostPatch? {
            if node.events?[.tapped] != nil { return node }

            for child in node.children {
                if let found = walk(child) { return found }
            }

            return nil
        }

        return walk(patch)
    }

    /// How big each card's FACE is drawn inside its placement - the press, and
    /// nothing else, since the placement itself is written a level above.
    private func faces(in patch: HostPatch) -> [PropValue] {
        var found: [PropValue] = []

        func walk(_ node: HostPatch) {
            if node.type == .text, let scale = node.props[.scale] { found.append(scale) }

            node.children.forEach(walk)
        }

        walk(patch)

        return found
    }

    /// A gallery nobody may swipe hears no hand: the user's hand is stopped,
    /// and the cards still stand where the run puts them.
    func testAGalleryNobodyMaySwipeHearsNoHand() {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).isSwipeEnabled(false).node }).whole

        XCTAssertNil(find(.phaseLayout, in: showing)?.events?[.handMoved])
        XCTAssertNotNil(find(.phaseLayout, in: showing))
    }

    /// And one with nothing to show shows what it was given instead.
    func testAnEmptyGalleryShowsWhatItWasGiven() {
        let renders = Renders()
        let patch = renders.render(
            GalleryView([Int]()) { number in Text("\(number)") }
                .emptyView(Text("nothing here"))
                .node)

        XCTAssertNil(find(.zStack, in: patch))
        XCTAssertEqual(find(.text, in: patch)?.props[.text], .string("nothing here"))
    }

    // MARK: - What the host is told

    /// The cards are placed by an ENGINE the host turns, so the message names
    /// two states - the run the placements ride on and the room they are worked
    /// out from - and turning one cycle answers where the cards go.
    func testTheCardsArePlacedByAStateTheHostTurns() throws {
        let renders = Renders()
        let showing = laid(renders, { self.gallery(3).node }).whole
        let placer = board(showing)

        XCTAssertEqual(placer.driven?[.area]?.kind, .placement)
        XCTAssertEqual(placer.driven?[.area]?.mode, .out)
        XCTAssertEqual(placer.driven?[.frame]?.kind, .feed)

        let run = placements(showing)

        guard run.count == 3 else {
            return XCTFail("the engine placed \(run.count) children of three, one a card")
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
        let bare = placements(laid(Renders(), { self.gallery(3).node }).whole)

        XCTAssertEqual(bare.first?.shade, Placement.unshaded, """
            a gallery given no shade view says so on every card, whatever \
            the arithmetic answered
            """)

        let shaded = placements(
            laid(Renders(), {
                self.gallery(3)
                    .shade(
                        Rectangle()
                            .fill(.black))
                    .node
            }).whole)

        XCTAssertEqual(shaded.first?.shade, 0, "the card in front wears none of it")
        XCTAssertTrue((shaded.card(2)?.shade ?? -1) > 0, "and a card behind it wears some")
    }

    /// A CHANGE OF SHAPE REACHES THE CARDS - end to end, through the number: the
    /// shape is read in the gallery's body, so another shape is a change of the
    /// description, and the engine the render arms again puts the cards where
    /// the new shape says.
    func testAChangeOfShapeReachesTheCards() {
        let renders = Renders()

        _ = laid(renders, { self.gallery(3).node })

        let lined = placements(renders.render(self.gallery(3).arrangement(.row).node))
        let fanned = placements(renders.render(self.gallery(3).arrangement(.fan).node))

        // THE CARD BEHIND, never the one in front: the front card stands in
        // the middle of the room whatever shape the run is in, and it is where
        // its NEIGHBORS go that the three shapes disagree about.
        guard let row = lined.card(2)?.bounds, let fan = fanned.card(2)?.bounds else {
            return XCTFail("the gallery placed no cards")
        }

        XCTAssertNotEqual(row, fan, "the cards stand where the shape they were last told puts them")
    }
}

private extension Array where Element == Placement {
    /// The placement of one card, or nil where the run placed none.
    func card(_ index: Int) -> Placement? {
        indices.contains(index) ? self[index] : nil
    }
}
