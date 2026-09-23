// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

// The MAUI host's list: what it describes, and what it does not.
//
// An ItemsView is made of controls that already cross the boundary - a
// ScrollView, an AbsoluteLayout, the items - so there is nothing on the host's
// side to check it against, and everything worth pinning is here: which slots
// a window holds, what a measurement does to the arithmetic, where a scroll
// takes the window, and that an item nobody can see is not described at all.

import XCTest
@_spi(Host) @testable import StateUI

final class ItemsViewTests: XCTestCase {
    /// The display as it stood before the test, put back after it. A list
    /// nobody has measured draws its window against the SCREEN, so a display
    /// another test pushed would decide how many items this one sees.
    private var held: (width: Double, height: Double, density: Double) = (0, 0, 0)

    /// Where the clock the engines run on stands, so every cycle is a new
    /// instant - a cycle asked for the moment it already answered has nothing
    /// to do.
    private var turned = 0.0

    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()

        let display = StandardEnvironment.display
        held = (display.width, display.height, display.density)

        // No screen at all, which a list answers with a thousand device units.
        display.width = 0
        display.height = 0
        display.density = 0
    }

    override func tearDown() {
        let display = StandardEnvironment.display
        display.width = held.width
        display.height = held.height
        display.density = held.density

        Renderer.shared.clearInvalidation()
        super.tearDown()
    }

    // MARK: - Reading a list

    /// A list of numbered items, each showing its own number.
    private func list(_ count: Int) -> ItemsView<Range<Int>, Int> {
        ItemsView(0..<count) { number in
            Label("\(number)")
        }
    }

    /// The slots a patch describes, read off their identities - which is what
    /// a slot that merely stayed where it was carries, and all it carries.
    private func shown(_ patch: HostPatch) -> [String] {
        slotsOf(patch).compactMap {
            if case .manual(let identity) = $0.id { return identity }
            return nil
        }
    }

    /// The AbsoluteLayout the slots are placed in - the scroller's only child
    /// while the list is unfurnished.
    private func placer(_ patch: HostPatch) -> HostPatch {
        patch.children.first { $0.type == .absoluteLayout } ?? patch
    }

    /// Its children, which are the slots.
    private func slotsOf(_ patch: HostPatch) -> [HostPatch] {
        Array(placer(patch).children)
    }

    /// One frame report: eight numbers, of which these tests use the top, the
    /// width and the height.
    private func frame(y: Double = 0, height: Double) -> [PropValue] {
        [.numbers([0, y, 320, height, 0, y, 0, y])]
    }

    /// The same across: an x and a width, for a list that runs that way.
    private func frame(x: Double = 0, width: Double) -> [PropValue] {
        [.numbers([x, 0, width, 240, x, 0, x, 0])]
    }

    /// Where a slot's bounds put it along a list running down.
    private func bounds(_ patch: HostPatch, _ identity: String) -> (y: Double, height: Double)? {
        for slot in slotsOf(patch) {
            guard case .manual(let name) = slot.id, name == identity,
                  case .numbers(let box)? = slot.props[.absoluteLayoutBounds],
                  box.count == 4
            else { continue }

            return (box[1], box[3])
        }

        return nil
    }

    /// A list on screen: what the render after the measurements said, and the
    /// state its scroller's offset is carried on.
    private struct Showing {
        /// What the render after the measurements had to say.
        let patch: HostPatch

        /// The number of the state the scroller's offset rides on - read off
        /// the FIRST patch, since a tie is written once and a later patch says
        /// nothing about one that did not change.
        let offset: Int32
    }

    /// Renders, tells the first item it measured `itemSize` - where there is
    /// one to tell - tells the scroller it is `viewport` long, and renders
    /// again: the state a list is in the moment it is on screen.
    private func settled(
        _ renders: Renders,
        _ tree: () -> Node,
        itemSize: Double? = 44,
        viewport: Double = 440
    ) -> Showing {
        var patch = renders.render(tree())
        let offset = patch.driven?[.scrollOffset]?.state ?? -1

        if let itemSize {
            XCTAssertTrue(renders.fire(slotsOf(patch).first?.events?[.frameChanged] ?? -1,
                                       with: frame(height: itemSize)))
        }

        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1,
                                   with: frame(height: viewport)))

        patch = renders.render(tree())
        return Showing(patch: patch, offset: offset)
    }

    /// Scrolls the way the HOST does: the user's offset laid onto the state
    /// the scroller carries, and a cycle turned, which is where the list's
    /// engine reads it.
    private func scroll(_ offset: Int32, to point: Point) {
        let board = Renderer.shared.board(for: .display)

        // THE FIRST CYCLE OF ALL LATCHES rather than runs; every later one runs.
        board.cycle(now: turned, reducesMotion: false)
        turned += 16

        slid(offset, to: point)

        board.cycle(now: turned, reducesMotion: false)
        turned += 16
    }

    // MARK: - What an item carries

    /// AN ITEM ARRIVES, IT DOES NOT TRAVEL, and its author can still say
    /// otherwise.
    ///
    /// A list hands its controls round: the item scrolling into view is very
    /// often the one that just left the other end, wearing another item's
    /// words and widths - so a law on an item walks its insides across the
    /// screen while the user scrolls, and a motion left running on an item
    /// the tree then drops takes the application down.
    ///
    /// THE TRAP THIS PINS is one character wide: `MotionPlan(base:)` takes an
    /// OPTIONAL, so `base: .none` is `Optional.none` - a plan stating no law -
    /// where `Motion.none` is the law meaning "arrive". Written the first way,
    /// every item travels.
    func testAnItemArrivesUnlessItsAuthorSaysOtherwise() {
        let fade = State(1.0)

        // An OPACITY, because it is what a placed child still carries by the
        // application's own law - the placement and the size are the host's -
        // so a change of it travels unless something on the item says not.
        func faded(_ make: @escaping (Int) -> Element) -> HostPatch? {
            let renders = Renders()
            let tree = { ItemsView(0..<3, content: make).itemSize(44).body }

            renders.render(tree())
            fade.wrappedValue = 0.5

            let patch = renders.render(tree(), changed: Renderer.shared.pendingChanges)
            fade.wrappedValue = 1

            return slotsOf(patch).first
        }

        let arriving = faded { number in
            Label("\(number)").opacity(fade.wrappedValue)
        }

        XCTAssertEqual(arriving?.props[.opacity], .number(0.5),
                       "the opacity did not change, so this proves nothing")
        XCTAssertNil(arriving?.transitions[.opacity],
                     "the list writes Motion.none on the item's own root")

        let travelling = faded { number in
            Label("\(number)").opacity(fade.wrappedValue).motion(.spring())
        }

        XCTAssertEqual(travelling?.transitions[.opacity]?.motion, Motion.spring(),
                       "an author who states a law on the item's root keeps it")
    }

    // MARK: - Items of their own length

    /// Renders a list that measures every item until it is on screen: one item
    /// measured, the scroller measured, then a length for each slot of the
    /// window.
    private func each(
        _ renders: Renders,
        _ tree: () -> Node,
        _ lengths: [Double],
        viewport: Double = 400
    ) -> HostPatch {
        // An event map is sent only when the SET of handled events changes, so
        // every handler is remembered as it is first seen.
        var handlers: [String: Int] = [:]

        func remember(_ patch: HostPatch) {
            for slot in slotsOf(patch) {
                guard case .manual(let name) = slot.id,
                      let id = slot.events?[.frameChanged]
                else { continue }

                handlers[name] = id
            }
        }

        var patch = renders.render(tree())
        let scroller = patch.events?[.frameChanged] ?? -1
        remember(patch)

        XCTAssertTrue(renders.fire(slotsOf(patch).first?.events?[.frameChanged] ?? -1,
                                   with: frame(height: lengths.first ?? 44)))
        XCTAssertTrue(renders.fire(scroller, with: frame(height: viewport)))

        patch = renders.render(tree())
        remember(patch)

        for (index, length) in lengths.enumerated() {
            guard case .manual(let name)? = slotsOf(patch).indices.contains(index)
                ? slotsOf(patch)[index].id
                : nil,
                let id = handlers[name]
            else { continue }

            XCTAssertTrue(renders.fire(id, with: frame(height: length)))
        }

        // Described WHOLE, because a patch says only what changed and a slot
        // that merely stayed where it was carries nothing.
        return renders.renderFromScratch(tree())
    }

    /// `.uniform` gives every item the length ONE of them measured, which is
    /// what makes ten thousand items cost what ten do; `.individual` lets
    /// each item be itself.
    func testEveryItemIsMeasuredWhereTheListIsToldTo() {
        let renders = Renders()

        func tree() -> Node {
            list(6).itemSizing(.individual).body
        }

        let patch = each(renders, tree, [30, 90, 60, 30, 30, 30])

        // Every described slot is subscribed, not just the first: each is its
        // own length, and an item whose content changes is a new length.
        for slot in slotsOf(patch) {
            XCTAssertNotNil(slot.events?[.frameChanged], "\(slot.id) measures itself")
        }

        // Each item starts where the one before it ended.
        XCTAssertEqual(bounds(patch, "0")?.y, 0)
        XCTAssertEqual(bounds(patch, "1")?.y, 30)
        XCTAssertEqual(bounds(patch, "2")?.y, 120)
        XCTAssertEqual(bounds(patch, "3")?.y, 180)
    }

    /// The run is as long as its items actually are, which is what the
    /// scroller is told.
    func testTheRunIsAsLongAsTheItemsMeasured() {
        let renders = Renders()

        func tree() -> Node {
            list(4).itemSizing(.individual).body
        }

        let patch = each(renders, tree, [20, 40, 60, 80])

        XCTAssertEqual(placer(patch).props[.height], .number(200))
    }

    /// An item keeps its measurement through an insertion: lengths are filed
    /// under the item's IDENTITY, so an item that moves down takes its length
    /// with it rather than inheriting its new neighbour's.
    func testAMeasuredItemKeepsItsLengthWhenAnotherIsInsertedBeforeIt() {
        let renders = Renders()
        var items = ["a", "b"]

        func tree() -> Node {
            ItemsView(items, id: \.self) { name in Label(name) }
                .itemSizing(.individual)
                .body
        }

        var patch = each(renders, tree, [25, 75])

        XCTAssertEqual(bounds(patch, "b")?.y, 25)

        items = ["c", "a", "b"]
        patch = renders.renderFromScratch(tree())

        // "c" has never been measured, so it is worth what one item is worth -
        // the first measurement that landed; "a" and "b" are still 25 and 75.
        XCTAssertEqual(bounds(patch, "a")?.y, 25)
        XCTAssertEqual(bounds(patch, "b")?.y, 50)
    }

    // MARK: - The window

    func testNothingIsDescribedBeyondTheFirstItemUntilOneIsMeasured() {
        let patch = Renders().render(list(10_000).body)

        XCTAssertEqual(patch.type, .scrollView, "the list IS a scroller, from the outside")
        XCTAssertEqual(shown(patch), ["0"],
                       "the first slot of the one kind with no length yet - and measuring "
                        + "it is what the rest of the arithmetic waits for")
    }

    func testOnlyTheItemsThatCanBeSeenAreDescribed() {
        let renders = Renders()
        let showing = settled(renders, { self.list(10_000).body })

        // Ten items fit in 440 units, and the margin after them.
        XCTAssertEqual(shown(showing.patch), (0...15).map(String.init))
    }

    func testTheMeasuredItemDecidesTheWholeListsLength() {
        let renders = Renders()
        let showing = settled(renders, { self.list(10_000).body })

        XCTAssertEqual(placer(showing.patch).props[.height], .number(10_000 * 44),
                       "the count times one measured item - which is what the scroller "
                        + "needs and the only thing it needs")
    }

    func testAStatedLengthIsNotMeasuredAtAll() {
        let patch = Renders().render(list(500).itemSize(30).body)

        XCTAssertEqual(placer(patch).props[.height], .number(500 * 30),
                       "a stated length is known before anything is drawn")
        XCTAssertNil(slotsOf(patch).first?.events?[.frameChanged],
                     "and nothing is subscribed to a measurement nobody is waiting for")
    }

    /// A length that is not above nought is no length: the list measures its
    /// first item instead, as though nothing had been stated.
    func testALengthThatIsNotALengthIsMeasuredInstead() {
        for length in [0, -44, Double.nan] {
            let patch = Renders().render(list(500).itemSize(length).body)

            XCTAssertEqual(shown(patch), ["0"], "\(length) was taken as a length")
            XCTAssertNotNil(slotsOf(patch).first?.events?[.frameChanged],
                            "\(length) left the first item unmeasured")
        }
    }

    /// The scroller's own measurement is an OPTIMIZATION, not a requirement:
    /// while it has not arrived, the screen is what the window is drawn
    /// against, because no list is longer than the window it is in.
    func testAListNobodyHasMeasuredFallsBackToAScreenful() {
        // With no screen at all, a thousand units: twenty items of fifty, and
        // the margin after them.
        XCTAssertEqual(shown(Renders().render(list(10_000).itemSize(50).body)).count, 26)

        // 1600 pixels at two pixels a unit is 800 units: sixteen items, and the
        // margin.
        StandardEnvironment.display.height = 1_600
        StandardEnvironment.display.density = 2

        XCTAssertEqual(shown(Renders().render(list(10_000).itemSize(50).body)).count, 22)
    }

    func testAScrollMovesTheWindowAndCarriesTheItemsWithIt() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        // Item 100 to the top of a 440-unit viewport.
        scroll(showing.offset, to: Point(0, 4400))

        XCTAssertEqual(shown(renders.render(tree())), (94...115).map(String.init),
                       "the items around the user, and the margin either side")
    }

    /// A FRAME OF A SCROLL RENDERS NOBODY while the slot at the top stays: the
    /// offset is carried by the host, the engine that reads it writes only a
    /// changed slot, and the list has nothing to describe.
    func testAScrollWithinTheSameItemDescribesNothingAgain() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        Renderer.shared.clearInvalidation()
        scroll(showing.offset, to: Point(0, 20))

        XCTAssertFalse(Renderer.shared.needsRender, "a scroll within one item asked for a render")
        XCTAssertTrue(renders.render(tree()).isEmpty,
                      "a scroll that leaves the top item where it was moves no window")
    }

    /// The list hears every frame the host reports and renders once per item
    /// crossed - never once per frame.
    func testAScrollRendersOncePerItemCrossedAndNeverPerFrame() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        Renderer.shared.clearInvalidation()

        for y in [8.0, 16, 24, 32, 40] {
            scroll(showing.offset, to: Point(0, y))
            XCTAssertFalse(Renderer.shared.needsRender, "a frame at \(y) rendered")
        }

        scroll(showing.offset, to: Point(0, 48))
        XCTAssertTrue(Renderer.shared.needsRender, "crossing into the next item rendered nothing")
    }

    /// A reading from outside is not a number until it is checked: an offset
    /// that is not a finite number moves no window - and asks no whole number
    /// of it, which is a trap rather than an answer.
    func testAnOffsetThatIsNotANumberLeavesTheWindowAlone() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        for y in [Double.nan, .infinity] {
            Renderer.shared.clearInvalidation()
            scroll(showing.offset, to: Point(0, y))

            XCTAssertFalse(Renderer.shared.needsRender, "\(y) moved the window")
        }

        XCTAssertTrue(renders.render(tree()).isEmpty)
    }

    /// An item is placed by its number, in device units, and across the axis
    /// it is as long as the scroller measured.
    func testEveryItemIsPlacedWhereItsNumberSaysAndFillsTheWidth() {
        let renders = Renders()
        let slots = slotsOf(settled(renders, { self.list(1_000).body }).patch)

        XCTAssertEqual(slots[0].props[.absoluteLayoutBounds], Rect(0, 0, 320, 44).propValue)
        XCTAssertEqual(slots[3].props[.absoluteLayoutBounds], Rect(0, 132, 320, 44).propValue)
        XCTAssertNil(slots[3].props[.absoluteLayoutProportions],
                     "every number of the bounds is a length, none a fraction")
    }

    func testAnItemWearsItsElementsIdentity() {
        let renders = Renders()
        let showing = settled(renders, { self.list(1_000).body })

        XCTAssertEqual(slotsOf(showing.patch).prefix(3).map(\.id),
                       [.manual("0"), .manual("1"), .manual("2")],
                       "the element IS the item's identity")
    }

    // MARK: - The furniture

    func testTheHeaderAndFooterRideBeforeAndAfterTheItems() {
        let patch = Renders().render(
            list(50)
                .header(Label("Top"))
                .footer(Label("Bottom"))
                .body)

        XCTAssertEqual(patch.children.map(\.type), [.label, .absoluteLayout, .label])
        XCTAssertEqual(patch.children.first?.props[.text], .string("Top"))
        XCTAssertEqual(patch.children.last?.props[.text], .string("Bottom"))
    }

    func testAnEmptyListShowsWhatItWasGivenInsteadOfItems() {
        let patch = Renders().render(
            list(0)
                .header(Label("Top"))
                .emptyView(Label("Nothing here"))
                .body)

        XCTAssertEqual(patch.children.map(\.type), [.label, .label])
        XCTAssertEqual(patch.children.last?.props[.text], .string("Nothing here"),
                       "and the header stays")
    }

    /// A list whose items all go leaves no item behind: its scroller is told
    /// that what it held is gone. Said by nothing, the host would go on
    /// showing the items it had until items came back.
    func testAListThatEmptiesLeavesNoItemBehind() {
        let renders = Renders()

        XCTAssertFalse(slotsOf(settled(renders, { self.list(3).body }).patch).isEmpty)

        let emptied = renders.render(list(0).body)

        XCTAssertTrue(emptied.arranged, "the scroller's children are said, as a whole")
        XCTAssertTrue(emptied.children.isEmpty, "and there are none")
    }

    // MARK: - Groups

    /// Two shelves, each with a header and a footer.
    private func shelves() -> ItemsView<[String], String> {
        ItemsView(groups: [
            ItemsGroup(["Apple", "Pear"]) { Label($0) }
                .id("fruit")
                .header(Label("Fruit"))
                .footer(Label("2 items")),
            ItemsGroup(["Leek"]) { Label($0) }
                .id("veg")
                .header(Label("Veg"))
                .footer(Label("1 item")),
        ])
    }

    /// A grouped list on screen: the header and the footer measured, the item
    /// length stated, the viewport long enough for every slot.
    private func settledShelves(_ renders: Renders, _ tree: () -> Node) -> HostPatch {
        let patch = renders.render(tree())
        let measuring = slotsOf(patch)

        XCTAssertEqual(measuring.count, 2,
                       "the first header and the first footer - the two kinds with no "
                        + "length yet, wherever in the list they fall")

        XCTAssertTrue(renders.fire(measuring[0].events?[.frameChanged] ?? -1,
                                   with: frame(height: 30)))
        XCTAssertTrue(renders.fire(measuring[1].events?[.frameChanged] ?? -1,
                                   with: frame(height: 10)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1, with: frame(height: 400)))

        return renders.render(tree())
    }

    func testAGroupsHeaderAndFooterAreSlotsAmongItsItems() {
        let renders = Renders()
        let patch = settledShelves(renders, { self.shelves().itemSize(20).body })

        XCTAssertEqual(shown(patch),
                       ["fruit/header", "fruit/Apple", "fruit/Pear", "fruit/footer",
                        "veg/header", "veg/Leek", "veg/footer"],
                       "one run of slots, in order, each identified by its group")
    }

    func testEachKindOfSlotIsMeasuredOnceAndAnswersForAllOfThem() {
        let renders = Renders()
        let patch = settledShelves(renders, { self.shelves().itemSize(20).body })

        // Fruit: 30 + 2x20 + 10. Veg: 30 + 20 + 10.
        XCTAssertEqual(placer(patch).props[.height], .number(80 + 60))

        let slots = slotsOf(patch)
        XCTAssertEqual(slots[1].props[.absoluteLayoutBounds], Rect(0, 30, 320, 20).propValue)
        XCTAssertEqual(slots[3].props[.absoluteLayoutBounds], Rect(0, 70, 320, 10).propValue)
        XCTAssertEqual(slots[4].props[.absoluteLayoutBounds], Rect(0, 80, 320, 30).propValue,
                       "the second group starts where the first one ended")
    }

    func testTwoGroupsMayHoldEqualItemsAndKeepTheirOwn() {
        let renders = Renders()
        let tree = {
            ItemsView(groups: [
                ItemsGroup(["Apple"]) { Label($0) }.id("left"),
                ItemsGroup(["Apple"]) { Label($0) }.id("right"),
            ])
            .itemSize(20)
            .body
        }

        // Nothing to measure - the length was stated and there are no headers.
        XCTAssertEqual(shown(renders.render(tree())), ["left/Apple", "right/Apple"],
                       "an item is named under its group, so equal items are still two")
    }

    /// A LENGTH MEASURED ALONG ONE AXIS IS NOT A LENGTH ALONG THE OTHER.
    ///
    /// An item measured 44 TALL says nothing about how WIDE it is, so a list
    /// turned to run across measures its items again rather than laying the
    /// run out at 44 an item.
    func testTurningAListThatMeasuresItsItemsMeasuresThemAgain() {
        let renders = Renders()
        let sideways = State(false)
        let tree = {
            self.list(10)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        let showing = settled(renders, tree)
        XCTAssertEqual(placer(showing.patch).props[.height], .number(10 * 44))

        // The turn is noticed after the render that made it, the way every
        // `.onChanged` is - so the run is put back on the next one.
        sideways.wrappedValue = true
        renders.render(tree())

        let turned = renders.renderFromScratch(tree())

        XCTAssertNotEqual(placer(turned).props[.width], .number(10 * 44),
                          "a height was laid out as a width")
        XCTAssertEqual(shown(turned), ["0"],
                       "the run is provisional again until an item has been measured across")
    }

    /// And a turn forgets EVERY length measured along the other axis - a
    /// group's header and footer included, which are measured whether or not
    /// the items' length is stated.
    func testTurningAListForgetsEveryLengthItMeasuredAlongTheOtherAxis() {
        let renders = Renders()
        let sideways = State(false)
        let tree = {
            self.shelves()
                .itemSize(20)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        XCTAssertEqual(shown(settledShelves(renders, tree)).count, 7)

        sideways.wrappedValue = true
        renders.render(tree())

        XCTAssertEqual(shown(renders.renderFromScratch(tree())), ["fruit/header", "fruit/footer"],
                       "a header's height was kept as its width")
    }

    /// And a group that says NOTHING is identified by where it sits, exactly
    /// as its header is.
    ///
    /// Left out, two groups holding equal items write one identity twice, and
    /// scrolling the first one out promotes the survivor onto the other item's
    /// element, taking that item's `@State` with it.
    func testAnUnnamedGroupIsIdentifiedByWhereItSits() {
        let renders = Renders()
        let tree = {
            ItemsView(groups: [
                ItemsGroup(["Apple"]) { Label($0) },
                ItemsGroup(["Apple"]) { Label($0) },
            ])
            .itemSize(20)
            .body
        }

        XCTAssertEqual(shown(renders.render(tree())), ["0/Apple", "1/Apple"])
    }

    /// Two EQUAL elements are two items: the repeat is given a stable variant
    /// of the identity, so both are described, each keeps its own control and
    /// state, and the variant is the same every render.
    func testTwoEqualElementsAreTwoItems() {
        let renders = Renders()
        let tree = {
            ItemsView(["a", "b", "a"]) { Label($0) }.itemSize(40).body
        }

        let first = renders.render(tree())
        let ids = slotsOf(first).map(\.id)

        XCTAssertEqual(slotsOf(first).map { $0.props[.text] }, [.string("a"), .string("b"), .string("a")])
        XCTAssertEqual(Set(ids).count, 3, "the repeated element wrote one identity twice")
        XCTAssertEqual(slotsOf(renders.renderFromScratch(tree())).map(\.id), ids,
                       "the variant moved between two renders, so the repeat rebuilds")
    }

    /// A list of ONE group prefixes nothing: its items are the only ones there
    /// are, and an author aiming an act at an item names the element they
    /// wrote.
    func testAListOfOneGroupNamesItsItemsByTheElementAlone() {
        let renders = Renders()
        let tree = {
            ItemsView(["Apple", "Pear"]) { Label($0) }
                .itemSize(20)
                .body
        }

        XCTAssertEqual(shown(renders.render(tree())), ["Apple", "Pear"])
    }

    /// A list EMPTIED and REFILLED describes its items again: the measurement
    /// survives - it is the template's, not any item's - and the scroller,
    /// stopped while there was nothing to scroll, runs again.
    func testAListEmptiedAndRefilledDescribesItsItemsAgain() {
        let renders = Renders()
        let count = State(3)
        let tree = {
            ItemsView(0..<count.wrappedValue) { Label("\($0)") }
                .itemSize(44)
                .body
        }

        XCTAssertEqual(shown(renders.render(tree())), ["0", "1", "2"])

        count.wrappedValue = 0
        renders.render(tree())
        XCTAssertEqual(shown(renders.renderFromScratch(tree())), [],
                       "an emptied list still described items")

        count.wrappedValue = 3
        renders.render(tree())
        XCTAssertEqual(shown(renders.renderFromScratch(tree())), ["0", "1", "2"],
                       "the refilled list never came back")
    }

    func testTheWindowWalksFromOneGroupIntoTheNext() {
        let renders = Renders()
        let tree = {
            ItemsView(groups: (0..<10).map { group in
                ItemsGroup(Array(0..<20).map { "\(group)-\($0)" }) { Label($0) }
                    .id("g\(group)")
                    .header(Label("Group \(group)"))
            })
            .itemSize(10)
            .body
        }

        var patch = renders.render(tree())
        let offset = patch.driven?[.scrollOffset]?.state ?? -1

        XCTAssertTrue(renders.fire(slotsOf(patch)[0].events?[.frameChanged] ?? -1,
                                   with: frame(height: 10)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1, with: frame(height: 40)))
        renders.render(tree())

        // Each group is 10 + 20 x 10 = 210 units; 420 is the third group's
        // header, exactly.
        scroll(offset, to: Point(0, 420))
        patch = renders.render(tree())

        XCTAssertTrue(shown(patch).contains("g2/header"))
        XCTAssertTrue(shown(patch).contains("g1/1-19"), "the margin reaches back into group 1")
        XCTAssertTrue(shown(patch).contains("g2/2-3"))
        XCTAssertFalse(shown(patch).contains("g3/header"), "and nothing beyond the window")
    }

    // MARK: - Selection

    func testAListNobodyLentABindingHasNoTapAtAll() {
        let renders = Renders()
        let showing = settled(renders, { self.list(100).body })

        XCTAssertNil(slotsOf(showing.patch).first?.events?[.tapped],
                     "a list that is not selectable subscribes nothing")
    }

    func testTappingAnItemChoosesItAndTappingItAgainClearsIt() {
        let chosen = State<Int?>(nil)
        let renders = Renders()
        let tree = { self.list(100).selection(chosen.projectedValue).body }
        let showing = settled(renders, tree)

        let fifth = slotsOf(showing.patch)[5].events?[.tapped] ?? -1

        XCTAssertTrue(renders.fire(fifth))
        XCTAssertEqual(chosen.wrappedValue, 5)

        XCTAssertTrue(renders.fire(fifth))
        XCTAssertNil(chosen.wrappedValue, "a tap on the chosen item clears the choice")
    }

    func testAMultipleSelectionTogglesTheItemThatWasTapped() {
        let chosen = State<Set<Int>>([])
        let renders = Renders()
        let tree = { self.list(100).selection(chosen.projectedValue).body }
        let showing = settled(renders, tree)

        let slots = slotsOf(showing.patch)

        XCTAssertTrue(renders.fire(slots[5].events?[.tapped] ?? -1))
        XCTAssertTrue(renders.fire(slots[7].events?[.tapped] ?? -1))
        XCTAssertEqual(chosen.wrappedValue, [5, 7])

        XCTAssertTrue(renders.fire(slots[5].events?[.tapped] ?? -1))
        XCTAssertEqual(chosen.wrappedValue, [7], "the others are kept - one tap moves one item")
    }

    // MARK: - The end

    /// Scrolls, and renders: the render is where a changed top slot is noticed
    /// and the end asked about.
    private func scrolled(_ renders: Renders, _ tree: () -> Node, _ offset: Int32, to y: Double) {
        scroll(offset, to: Point(0, y))
        renders.render(tree(), changed: Renderer.shared.pendingChanges)
    }

    func testTheEndIsAskedForWithinTheItemsItWasGiven() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(60)
                .onEndReached(within: 8) { asked.wrappedValue += 1 }
                .body
        }

        let showing = settled(renders, tree)
        XCTAssertEqual(asked.wrappedValue, 0, "nobody has scrolled anywhere near the end")

        // Item 20 at the top of ten in view leaves thirty after them.
        scrolled(renders, tree, showing.offset, to: 880)
        XCTAssertEqual(asked.wrappedValue, 0)

        // Item 45 leaves five, which is within eight.
        scrolled(renders, tree, showing.offset, to: 1980)
        XCTAssertEqual(asked.wrappedValue, 1)
    }

    /// Nought, the default, is the last item coming into view - and not an
    /// item before it.
    func testTheDefaultAsksAsTheLastItemComesIntoView() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(60)
                .onEndReached { asked.wrappedValue += 1 }
                .body
        }

        let showing = settled(renders, tree)

        // Item 49 at the top shows items 49 to 58, and one is left after them.
        scrolled(renders, tree, showing.offset, to: 49 * 44)
        XCTAssertEqual(asked.wrappedValue, 0, "one item was still to come")

        scrolled(renders, tree, showing.offset, to: 50 * 44)
        XCTAssertEqual(asked.wrappedValue, 1)
    }

    /// Asked once per item the top moves by while the user is near the end,
    /// and never once per frame.
    func testTheEndIsAskedOncePerItemCrossedAndNeverPerFrame() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(60)
                .onEndReached(within: 8) { asked.wrappedValue += 1 }
                .body
        }

        let showing = settled(renders, tree)

        scrolled(renders, tree, showing.offset, to: 45 * 44)
        XCTAssertEqual(asked.wrappedValue, 1)

        scrolled(renders, tree, showing.offset, to: 45 * 44 + 20)
        XCTAssertEqual(asked.wrappedValue, 1, "a frame within the same item asked again")

        scrolled(renders, tree, showing.offset, to: 46 * 44)
        XCTAssertEqual(asked.wrappedValue, 2, "the next item crossed near the end asked nothing")
    }

    /// The end is counted in ITEMS: a group's footer after the last item is no
    /// item, so the last item in view is the end even before the footer is.
    func testTheEndIsCountedInItemsAndNotInHeadersOrFooters() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            ItemsView(groups: ["a", "b"].map { name in
                ItemsGroup((0..<10).map { "\(name)\($0)" }) { Label($0) }
                    .id(name)
                    .header(Label(name))
                    .footer(Label("end of \(name)"))
            })
            .itemSize(20)
            .onEndReached { asked.wrappedValue += 1 }
            .body
        }

        // Every slot twenty long, and five of them in a viewport of a hundred:
        // group a is slots 0 to 11, group b 12 to 23, and b's last item is 22.
        var patch = renders.render(tree())
        let offset = patch.driven?[.scrollOffset]?.state ?? -1
        let measuring = slotsOf(patch)

        XCTAssertTrue(renders.fire(measuring[0].events?[.frameChanged] ?? -1, with: frame(height: 20)))
        XCTAssertTrue(renders.fire(measuring[1].events?[.frameChanged] ?? -1, with: frame(height: 20)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1, with: frame(height: 100)))
        patch = renders.render(tree())

        // Slots 17 to 21 in view: b's item 8 is the last, and b9 is still to come.
        scrolled(renders, tree, offset, to: 17 * 20)
        XCTAssertEqual(asked.wrappedValue, 0)

        // Slots 18 to 22: the last item is in view, and the footer is not.
        scrolled(renders, tree, offset, to: 18 * 20)
        XCTAssertEqual(asked.wrappedValue, 1, "the footer after the last item was counted as one")
    }

    /// A list that fits in its view entirely has nothing to scroll, so no
    /// scroll ever says the user is at the end - and without another
    /// trigger the loading stalls after the first batch. The RUN's own frame
    /// is the second place the question can become true: it changes as the
    /// list grows, so the list asks again until it outgrows the view or the
    /// author's guard stops it.
    func testAListShorterThanItsViewStillAsksForMore() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(6)
                .onEndReached(within: 8) { asked.wrappedValue += 1 }
                .body
        }

        // The run's handler is read off the FIRST patch: an event map is sent
        // only when the set of handled events changes.
        var patch = renders.render(tree())
        let run = placer(patch).events?[.frameChanged] ?? -1

        XCTAssertTrue(renders.fire(slotsOf(patch).first?.events?[.frameChanged] ?? -1,
                                   with: frame(height: 44)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1,
                                   with: frame(height: 440)))

        patch = renders.render(tree())
        XCTAssertEqual(asked.wrappedValue, 0, "the run has not reported its frame yet")

        XCTAssertTrue(renders.fire(run, with: frame(height: 264)))
        XCTAssertEqual(asked.wrappedValue, 1,
                       "six items in a view that holds ten - the user is at the end "
                        + "already, and no scroll will ever say so")
    }

    /// And the VIEWPORT's frame is the third: a run that reports before its
    /// scroller does is asked about with nothing known of the view, and the
    /// scroller's report is what answers it.
    func testAListMeasuredAfterItsRunStillAsksForMore() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(6)
                .onEndReached(within: 8) { asked.wrappedValue += 1 }
                .body
        }

        var patch = renders.render(tree())
        let run = placer(patch).events?[.frameChanged] ?? -1
        let scroller = patch.events?[.frameChanged] ?? -1

        XCTAssertTrue(renders.fire(slotsOf(patch).first?.events?[.frameChanged] ?? -1,
                                   with: frame(height: 44)))
        patch = renders.render(tree())

        XCTAssertTrue(renders.fire(run, with: frame(height: 264)))
        XCTAssertEqual(asked.wrappedValue, 0, "asked with no view measured at all")

        XCTAssertTrue(renders.fire(scroller, with: frame(height: 440)))
        XCTAssertEqual(asked.wrappedValue, 1, "the view was measured and nobody asked")
    }

    // MARK: - What an item keeps

    func testAnItemsOwnStateBelongsToItsElementWhileTheWindowHoldsIt() {
        struct Row: ContentView {
            let number: Int
            @State var count = 0

            var content: any View {
                Button("\(number): \(count)").onClicked { count += 1 }
            }
        }

        let renders = Renders()
        let tree = { ItemsView(0..<1_000) { Row(number: $0) }.itemSize(44).body }
        let first = renders.render(tree())
        let offset = first.driven?[.scrollOffset]?.state ?? -1

        // Press item 2's button, then give the viewport its length and scroll
        // a little - both of which leave item 2 inside the window.
        XCTAssertTrue(renders.fire(slotsOf(first)[2].events?[.clicked] ?? -1))
        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(height: 440)))
        scroll(offset, to: Point(0, 44))

        let kept = slotsOf(renders.render(tree(), changed: Renderer.shared.pendingChanges))
            .first { $0.id == .manual("2") }

        XCTAssertEqual(kept?.props[.text], .string("2: 1"),
                       "the item stayed in the window, so its own state stayed with it")
    }

    // MARK: - The list's own numbers

    /// THE LIST'S OWN ARITHMETIC ARRIVES, IT DOES NOT TRAVEL: the run's length
    /// answers a measurement, and a length still on its way would be read as
    /// the answer by whatever asks next.
    func testTheRunsLengthArrivesRatherThanTravels() {
        let renders = Renders()
        let count = State(10)
        let tree = {
            ItemsView(0..<count.wrappedValue) { Label("\($0)") }
                .itemSize(44)
                .body
        }

        let first = renders.render(tree())
        XCTAssertEqual(placer(first).motion?.motion, Motion.none, "the run places its slots at once")

        count.wrappedValue = 11

        let grown = placer(renders.render(tree(), changed: Renderer.shared.pendingChanges))

        XCTAssertEqual(grown.props[.height], .number(11 * 44))
        XCTAssertNil(grown.transitions[.height], "the run's new length travelled")
    }

    /// A write to the offset with no law of its own is a JUMP: the list's
    /// scroller carries `Motion.none`, and that is the law the write goes out
    /// under. The host lands it and reports the landing, and the window
    /// follows the AUTHOR's state there.
    func testAWriteToTheOffsetWithNoLawOfItsOwnIsAJump() {
        let offset = State(Point.zero)
        let renders = Renders()
        let tree = { self.list(10_000).itemSize(44).scrollOffset(offset.projectedValue).body }
        let showing = settled(renders, tree, itemSize: nil)
        let board = Renderer.shared.board(for: .display)

        board.cycle(now: turned, reducesMotion: false)
        turned += 16

        offset.wrappedValue = Point(0, 4400)

        board.cycle(now: turned, reducesMotion: false)
        turned += 16

        let sent = standing(showing.offset, as: JourneyLanes<Point>.self)

        XCTAssertEqual(sent?.destination.y, 4400, "the write never reached the host")
        XCTAssertEqual(sent?.motion, Motion.none, "the offset set off on a trip nobody asked for")

        // The host puts the scroller there at once, and says where it stands.
        scroll(showing.offset, to: Point(0, 4400))

        XCTAssertEqual(shown(renders.render(tree(), changed: Renderer.shared.pendingChanges)).first,
                       "94", "the window stayed where the offset was")
    }

    /// The run is pinned where the scroller starts: a view stating a length is
    /// centred in whatever room is left over, so a list shorter than its own
    /// scroller would stand in the middle of it.
    func testTheRunStartsWhereTheScrollerDoes() {
        let patch = Renders().render(list(4).body)

        XCTAssertEqual(placer(patch).props[.verticalAlignment], Alignment.start.propValue)

        // And across the axis it fills, which gives an item the list's whole
        // width.
        XCTAssertEqual(placer(patch).props[.horizontalAlignment], Alignment.fill.propValue)
    }

    /// And a list that runs across is pinned the other way round.
    func testARunAcrossStartsAtItsLeadingEdge() {
        let patch = Renders().render(list(4).orientation(.horizontal).itemSize(80).body)

        XCTAssertEqual(placer(patch).props[.horizontalAlignment], Alignment.start.propValue)
        XCTAssertEqual(placer(patch).props[.verticalAlignment], Alignment.fill.propValue)
    }

    // MARK: - Running across

    /// A list told to run across places its items along the OTHER axis, and
    /// each takes the whole of the list's height rather than its width.
    func testRunningAcrossPlacesItemsAlongTheOtherAxis() {
        let renders = Renders()
        let tree = { self.list(1_000).orientation(.horizontal).itemSize(80).body }
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(width: 400)))

        // Described WHOLE: the arithmetic was right from the first render - the
        // length was stated - so a sparse patch has nothing to say about it.
        let patch = renders.renderFromScratch(tree())

        // The run is as long as the items are wide, and as tall as the
        // scroller, which a sideways scroller does not give its content itself.
        XCTAssertEqual(placer(patch).props[.width], .number(1_000 * 80))
        XCTAssertEqual(placer(patch).props[.height], .number(240))

        // Item 0 at the start, item 1 one item along, both the full height.
        XCTAssertEqual(slotsOf(patch)[0].props[.absoluteLayoutBounds], Rect(0, 0, 80, 240).propValue)
        XCTAssertEqual(slotsOf(patch)[1].props[.absoluteLayoutBounds], Rect(80, 0, 80, 240).propValue)
    }

    /// And it follows the offset across: a list that runs across is scrolled
    /// across, and the window is drawn around that.
    func testRunningAcrossFollowsTheOffsetAcross() {
        let renders = Renders()
        let tree = { self.list(1_000).orientation(.horizontal).itemSize(80).body }
        let first = renders.render(tree())
        let offset = first.driven?[.scrollOffset]?.state ?? -1

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(width: 400)))
        renders.render(tree())

        Renderer.shared.clearInvalidation()
        scroll(offset, to: Point(0, 80 * 20))

        XCTAssertFalse(Renderer.shared.needsRender, "a list running across followed the offset down")
        XCTAssertTrue(renders.render(tree()).isEmpty)

        scroll(offset, to: Point(80 * 20, 0))

        // Item 20 is at the edge, and the window is drawn around it.
        XCTAssertEqual(shown(renders.render(tree())).first, "14")
    }
}

#endif
