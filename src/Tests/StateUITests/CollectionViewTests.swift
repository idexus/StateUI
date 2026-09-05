// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's own list: what it describes, and what it does not.
//
// A CollectionView is made of controls that already exist - a ScrollView, an
// AbsoluteLayout, the rows - so there is nothing on the C# side to check it
// against, and everything worth pinning is on this side: which rows a window
// holds, what a measurement does to the geometry, where a scroll takes the
// window, and that a row nobody can see is not described at all.

import XCTest
@testable import StateUI

final class CollectionViewTests: XCTestCase {
    /// A list of numbered rows, each showing its own number.
    private func list(_ count: Int) -> CollectionView<Range<Int>, Int> {
        CollectionView(0..<count) { number in
            Label("\(number)")
        }
    }

    /// The rows a patch describes, read off their identities - which is what a
    /// row that merely stayed where it was carries, and all it carries.
    private func shown(_ patch: Patch) -> [String] {
        rowsOf(patch).compactMap {
            if case .manual(let identity) = $0.id { return identity }
            return nil
        }
    }

    /// The AbsoluteLayout the rows are placed in - the scroller's only child
    /// while the list is unfurnished.
    private func placer(_ patch: Patch) -> Patch {
        patch.children.first { $0.type == .absoluteLayout } ?? patch
    }

    /// Its children, which are the rows.
    private func rowsOf(_ patch: Patch) -> [Patch] {
        placer(patch).children
    }

    /// One frame report: eight numbers, of which these tests use the top and
    /// the height.
    private func frame(y: Double = 0, height: Double) -> [PropValue] {
        [.numbers([0, y, 320, height, 0, y, 0, y])]
    }

    /// The same across: an x and a width, for a list that runs that way.
    private func frame(x: Double = 0, width: Double) -> [PropValue] {
        [.numbers([x, 0, width, 240, x, 0, x, 0])]
    }

    /// A list on screen: what the second render said, and the handler the
    /// scroller reports through.
    ///
    /// The id is read off the FIRST patch on purpose - an event map is sent
    /// only when the set of handled events changes, so the second one says
    /// nothing about handlers that were already there.
    private struct Showing {
        /// What the render after the measurements had to say.
        let patch: Patch

        /// The scroller's own `scrollYChanged` handler.
        let scrollY: Int
    }

    /// Renders, tells the first row it measured `itemSize`, tells the
    /// scroller it is `viewport` tall, and renders again - which is the state a
    /// list is in the moment it is on screen.
    private func settled(
        _ renders: Renders,
        _ tree: () -> Node,
        itemSize: Double = 44,
        viewport: Double = 440
    ) -> Showing {
        var patch = renders.render(tree())
        let scrollY = patch.events?[.scrollYChanged] ?? -1

        XCTAssertTrue(renders.fire(rowsOf(patch).first?.events?[.frameChanged] ?? -1,
                                   with: frame(height: itemSize)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1,
                                   with: frame(height: viewport)))

        patch = renders.render(tree())
        return Showing(patch: patch, scrollY: scrollY)
    }

    // MARK: - Rows of their own size

    /// Renders a list that measures every item until it is on screen: one row
    /// measured, the scroller measured, then a height for each row of the
    /// window.
    private func each(
        _ renders: Renders,
        _ tree: () -> Node,
        _ heights: [Double],
        viewport: Double = 400
    ) -> Patch {
        // An event map is sent only when the SET of handled events changes, so
        // every handler is remembered as it is first seen and never asked for
        // twice.
        var handlers: [String: Int] = [:]

        func remember(_ patch: Patch) {
            for row in rowsOf(patch) {
                guard case .manual(let name) = row.id,
                      let id = row.events?[.frameChanged]
                else { continue }

                handlers[name] = id
            }
        }

        var patch = renders.render(tree())
        let scroller = patch.events?[.frameChanged] ?? -1
        remember(patch)

        XCTAssertTrue(renders.fire(rowsOf(patch).first?.events?[.frameChanged] ?? -1,
                                   with: frame(height: heights.first ?? 44)))
        XCTAssertTrue(renders.fire(scroller, with: frame(height: viewport)))

        patch = renders.render(tree())
        remember(patch)

        for (index, height) in heights.enumerated() {
            guard case .manual(let name)? = rowsOf(patch).indices.contains(index)
                ? rowsOf(patch)[index].id
                : nil,
                let id = handlers[name]
            else { continue }

            XCTAssertTrue(renders.fire(id, with: frame(height: height)))
        }

        // Described WHOLE, because a patch says only what changed and a row
        // that merely stayed where it was carries nothing.
        return renders.renderFromScratch(tree())
    }

    /// Where a row's bounds put it, along the list.
    private func bounds(_ patch: Patch, _ identity: String) -> (y: Double, height: Double)? {
        for row in rowsOf(patch) {
            guard case .manual(let name) = row.id, name == identity,
                  case .numbers(let box)? = row.props[.absoluteLayoutBounds],
                  box.count == 4
            else { continue }

            return (box[1], box[3])
        }

        return nil
    }

    /// The default gives every row the size ONE of them measured, which is
    /// what makes a list of ten thousand cost what a list of ten does.
    /// `.measureAllItems` lets each row be itself.
    func testEveryRowIsMeasuredWhereTheListIsToldTo() {
        let renders = Renders()

        func tree() -> Node {
            list(6).itemSizingStrategy(.measureAllItems).body
        }

        let patch = each(renders, tree, [30, 90, 60, 30, 30, 30])

        // Every described row is subscribed, not just the first: each one is
        // its own size, and a row whose content changes is a new size.
        for row in rowsOf(patch) {
            XCTAssertNotNil(row.events?[.frameChanged], "\(row.id) measures itself")
        }

        // Each row starts where the one above it ended.
        XCTAssertEqual(bounds(patch, "0")?.y, 0)
        XCTAssertEqual(bounds(patch, "1")?.y, 30)
        XCTAssertEqual(bounds(patch, "2")?.y, 120)
        XCTAssertEqual(bounds(patch, "3")?.y, 180)
    }

    /// The run is as long as its rows actually are, which is what the scroller
    /// is told.
    func testTheRunIsAsLongAsTheRowsMeasured() {
        let renders = Renders()

        func tree() -> Node {
            list(4).itemSizingStrategy(.measureAllItems).body
        }

        let patch = each(renders, tree, [20, 40, 60, 80])

        XCTAssertEqual(placer(patch).props[.heightRequest], .number(200))
    }

    /// A row keeps its measurement through an insertion: heights are filed
    /// under the row's IDENTITY, so a row that moves down takes its size with
    /// it rather than inheriting its new neighbour's.
    func testAMeasuredRowKeepsItsSizeWhenAnotherIsInsertedAboveIt() {
        let renders = Renders()
        var items = ["a", "b"]

        func tree() -> Node {
            CollectionView(items, id: \.self) { name in Label(name) }
                .itemSizingStrategy(.measureAllItems)
                .body
        }

        var patch = each(renders, tree, [25, 75])

        XCTAssertEqual(bounds(patch, "b")?.y, 25)

        items = ["c", "a", "b"]
        patch = renders.renderFromScratch(tree())

        // "c" has never been measured, so it is worth what one row is worth -
        // the first measurement that landed; "a" and "b" are still 25 and 75.
        XCTAssertEqual(bounds(patch, "a")?.y, 25)
        XCTAssertEqual(bounds(patch, "b")?.y, 50)
    }

    // MARK: - The window

    func testNothingIsDescribedBeyondTheFirstRowUntilOneIsMeasured() {
        let patch = Renders().render(list(10_000).body)

        XCTAssertEqual(patch.type, .scrollView, "the list IS a scroller, from the outside")
        XCTAssertEqual(shown(patch), ["0"],
                       "the first slot of the one kind with no height yet - and measuring "
                        + "it is what the rest of the geometry waits for")
    }

    func testOnlyTheRowsThatCanBeSeenAreDescribed() {
        let renders = Renders()
        let showing = settled(renders, { self.list(10_000).body })

        // Ten rows fit in 440 points, plus the margin below them.
        XCTAssertEqual(shown(showing.patch), (0...15).map(String.init))
    }

    func testTheMeasuredRowDecidesTheWholeListsHeight() {
        let renders = Renders()
        let showing = settled(renders, { self.list(10_000).body })

        XCTAssertEqual(placer(showing.patch).props[.heightRequest], .number(10_000 * 44),
                       "the count times one measured row - which is what the scroller "
                        + "needs and the only thing it needs")
    }

    func testAStatedRowHeightIsNotMeasuredAtAll() {
        let patch = Renders().render(list(500).itemSize(30).body)

        XCTAssertEqual(placer(patch).props[.heightRequest], .number(500 * 30),
                       "a stated height is known before anything is drawn")
        XCTAssertNil(rowsOf(patch).first?.events?[.frameChanged],
                     "and nothing is subscribed to a measurement nobody is waiting for")
    }

    /// The scroller's own measurement is an OPTIMIZATION, not a requirement:
    /// while it has not arrived, a screenful is what the window is drawn
    /// against, because no list is taller than the window it is in. Measured
    /// on a CPH2363, where trusting the report alone left a band of nothing
    /// under the last row.
    func testAListNobodyHasMeasuredFallsBackToAScreenful() {
        let patch = Renders().render(list(10_000).itemSize(50).body)

        // Headless, the screen answers a thousand points: twenty rows of
        // fifty, and the margin below them.
        XCTAssertEqual(shown(patch).count, 26)
    }

    func testAScrollMovesTheWindowAndCarriesTheRowsWithIt() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        // Row 100 to the top of a 440-point viewport.
        XCTAssertTrue(renders.fire(showing.scrollY, with: [.number(4400)]))

        XCTAssertEqual(shown(renders.render(tree())), (94...115).map(String.init),
                       "the rows around the reader, and the margin either side")
    }

    func testAScrollWithinTheSameRowDescribesNothingAgain() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        XCTAssertTrue(renders.fire(showing.scrollY, with: [.number(20)]))

        XCTAssertTrue(renders.render(tree()).isEmpty,
                      "a scroll that leaves the top row where it was moves no window, "
                        + "so the render has nothing to say")
    }

    func testARowThatWillNotReadLeavesTheWindowAlone() {
        let renders = Renders()
        let tree = { self.list(10_000).body }
        let showing = settled(renders, tree)

        XCTAssertTrue(renders.fire(showing.scrollY, with: [.string("far")]))

        XCTAssertTrue(renders.render(tree()).isEmpty,
                      "a payload of the wrong shape is a version mismatch, not a scroll")
    }

    func testEveryRowIsPlacedWhereItsNumberSaysAndFillsTheWidth() {
        let renders = Renders()
        let rows = rowsOf(settled(renders, { self.list(1_000).body }).patch)

        XCTAssertEqual(rows[0].props[.absoluteLayoutBounds], Rect(0, 0, 1, 44).propValue)
        XCTAssertEqual(rows[3].props[.absoluteLayoutBounds], Rect(0, 132, 1, 44).propValue)
        XCTAssertEqual(rows[3].props[.absoluteLayoutFlags],
                       AbsoluteLayoutFlags.widthProportional.propValue,
                       "the width is a fraction of the layout, the height the measured one")
    }

    func testARowWearsItsItemsIdentity() {
        let renders = Renders()
        let showing = settled(renders, { self.list(1_000).body })

        XCTAssertEqual(rowsOf(showing.patch).prefix(3).map(\.id),
                       [.manual("0"), .manual("1"), .manual("2")],
                       "the item IS the row's identity - ForEach's rule, as everywhere else")
    }

    // MARK: - The furniture

    func testTheHeaderAndFooterRideAboveAndBelowTheRows() {
        let patch = Renders().render(
            list(50)
                .header(Label("Top"))
                .footer(Label("Bottom"))
                .body)

        XCTAssertEqual(patch.children.map(\.type), [.label, .absoluteLayout, .label])
        XCTAssertEqual(patch.children.first?.props[.text], .string("Top"))
        XCTAssertEqual(patch.children.last?.props[.text], .string("Bottom"))
    }

    func testAnEmptyListShowsWhatItWasGivenInsteadOfRows() {
        let patch = Renders().render(
            list(0)
                .header(Label("Top"))
                .emptyView(Label("Nothing here"))
                .body)

        XCTAssertEqual(patch.children.map(\.type), [.label, .label])
        XCTAssertEqual(patch.children.last?.props[.text], .string("Nothing here"),
                       "and the header stays, which is not every platform's answer for MAUI's own")
    }

    // MARK: - Groups

    /// Two shelves, the first with a heading and a footing.
    private func shelves() -> CollectionView<[String], String> {
        CollectionView(groups: [
            CollectionGroup(["Apple", "Pear"]) { Label($0) }
                .id("fruit")
                .header(Label("Fruit"))
                .footer(Label("2 items")),
            CollectionGroup(["Leek"]) { Label($0) }
                .id("veg")
                .header(Label("Veg"))
                .footer(Label("1 item")),
        ])
    }

    /// A grouped list on screen: the heading and the footing measured, the row
    /// height stated, the viewport wide enough for every slot.
    private func settledShelves(_ renders: Renders, _ tree: () -> Node) -> Patch {
        let patch = renders.render(tree())
        let measuring = rowsOf(patch)

        XCTAssertEqual(measuring.count, 2,
                       "the first heading and the first footing - the two kinds with no "
                        + "height yet, wherever in the list they fall")

        XCTAssertTrue(renders.fire(measuring[0].events?[.frameChanged] ?? -1,
                                   with: frame(height: 30)))
        XCTAssertTrue(renders.fire(measuring[1].events?[.frameChanged] ?? -1,
                                   with: frame(height: 10)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1, with: frame(height: 400)))

        return renders.render(tree())
    }

    func testAGroupsHeadingAndFootingAreSlotsAmongItsRows() {
        let renders = Renders()
        let patch = settledShelves(renders, { self.shelves().itemSize(20).body })

        XCTAssertEqual(shown(patch),
                       ["fruit/heading", "fruit/Apple", "fruit/Pear", "fruit/footing",
                        "veg/heading", "veg/Leek", "veg/footing"],
                       "one run of slots, in order, each identified by its group")
    }

    func testEachKindOfSlotIsMeasuredOnceAndAnswersForAllOfThem() {
        let renders = Renders()
        let patch = settledShelves(renders, { self.shelves().itemSize(20).body })

        // Fruit: 30 + 2x20 + 10. Veg: 30 + 20 + 10.
        XCTAssertEqual(placer(patch).props[.heightRequest], .number(80 + 60))

        let rows = rowsOf(patch)
        XCTAssertEqual(rows[1].props[.absoluteLayoutBounds], Rect(0, 30, 1, 20).propValue)
        XCTAssertEqual(rows[3].props[.absoluteLayoutBounds], Rect(0, 70, 1, 10).propValue)
        XCTAssertEqual(rows[4].props[.absoluteLayoutBounds], Rect(0, 80, 1, 30).propValue,
                       "the second group starts where the first one ended")
    }

    func testTwoGroupsMayHoldEqualItemsAndKeepTheirOwnRows() {
        let renders = Renders()
        let tree = {
            CollectionView(groups: [
                CollectionGroup(["Apple"]) { Label($0) }.id("left"),
                CollectionGroup(["Apple"]) { Label($0) }.id("right"),
            ])
            .itemSize(20)
            .body
        }

        // Nothing to measure - the rows were stated and there are no headings.
        XCTAssertEqual(shown(renders.render(tree())), ["left/Apple", "right/Apple"],
                       "a row is named under its group, so equal items are still two rows")
    }

    /// A LENGTH MEASURED ALONG ONE AXIS IS NOT A LENGTH ALONG THE OTHER.
    ///
    /// A row measured 44 TALL says nothing about how WIDE it is, so a list
    /// turned to run across measures its rows again rather than laying the run
    /// out at 44 a row. Carried across, the run came out at a fraction of its
    /// length and every row was placed inside it.
    func testTurningAListThatMeasuresItsRowsMeasuresThemAgain() {
        let renders = Renders()
        let sideways = State(false)
        let tree = {
            self.list(10)
                .orientation(sideways.wrappedValue ? .horizontal : .vertical)
                .body
        }

        let showing = settled(renders, tree)
        XCTAssertEqual(placer(showing.patch).props[.heightRequest], .number(10 * 44))

        // The turn is noticed after the render that made it, the way every
        // `.onChanged` is - so the run is put back on the next one.
        sideways.wrappedValue = true
        renders.render(tree())

        let turned = renders.renderFromScratch(tree())

        XCTAssertNotEqual(placer(turned).props[.widthRequest], .number(10 * 44),
                          "a height was laid out as a width")
        XCTAssertEqual(shown(turned), ["0"],
                       "the run is provisional again until a row has been measured across")
    }

    /// And a group that says NOTHING is identified by where it sits, exactly as
    /// its heading is.
    ///
    /// Left out, two groups holding equal items wrote one identity twice, and
    /// the second row was told apart only by where it stood in the window -
    /// so scrolling the first one out promoted the survivor onto the other
    /// item's element, taking that item's `@State` with it.
    func testAnUnnamedGroupIsIdentifiedByWhereItSits() {
        let renders = Renders()
        let tree = {
            CollectionView(groups: [
                CollectionGroup(["Apple"]) { Label($0) },
                CollectionGroup(["Apple"]) { Label($0) },
            ])
            .itemSize(20)
            .body
        }

        XCTAssertEqual(shown(renders.render(tree())), ["0/Apple", "1/Apple"])
    }

    /// Two EQUAL items are two rows: the repeat is given a stable variant of
    /// the identity - the id with an occurrence number behind a NUL, which no
    /// author-written id can collide with - so both rows are described, each
    /// keeps its own control and state, and the variant is the same every
    /// render.
    func testTwoEqualItemsAreTwoRows() {
        let renders = Renders()
        let tree = {
            CollectionView(["a", "b", "a"]) { Label($0) }.itemSize(40).body
        }

        let first = renders.render(tree())
        let ids = rowsOf(first).map(\.id)

        XCTAssertEqual(rowsOf(first).map { $0.props[.text] }, [.string("a"), .string("b"), .string("a")])
        XCTAssertEqual(Set(ids).count, 3, "the repeated item wrote one identity twice")
        XCTAssertEqual(rowsOf(renders.renderFromScratch(tree())).map(\.id), ids,
                       "the variant moved between two renders, so the repeat rebuilds")
    }

    /// A list of ONE group prefixes nothing: its rows are the only ones there
    /// are, and an author aiming an act at a row names the item they wrote.
    func testAListOfOneGroupNamesItsRowsByTheItemAlone() {
        let renders = Renders()
        let tree = {
            CollectionView(["Apple", "Pear"]) { Label($0) }
                .itemSize(20)
                .body
        }

        XCTAssertEqual(shown(renders.render(tree())), ["Apple", "Pear"])
    }

    /// A list EMPTIED and REFILLED describes its rows again: the measurement
    /// survives - it is the template's, not any row's - and the scroller,
    /// stopped while there was nothing to scroll, runs again.
    func testAListEmptiedAndRefilledDescribesItsRowsAgain() {
        let renders = Renders()
        let count = State(3)
        let tree = {
            CollectionView(0..<count.wrappedValue) { Label("\($0)") }
                .itemSize(44)
                .body
        }

        XCTAssertEqual(shown(renders.render(tree())), ["0", "1", "2"])

        count.wrappedValue = 0
        renders.render(tree())
        XCTAssertEqual(shown(renders.renderFromScratch(tree())), [],
                       "an emptied list still described rows")

        count.wrappedValue = 3
        renders.render(tree())
        XCTAssertEqual(shown(renders.renderFromScratch(tree())), ["0", "1", "2"],
                       "the refilled list never came back")
    }

    func testTheWindowWalksFromOneGroupIntoTheNext() {
        let renders = Renders()
        let tree = {
            CollectionView(groups: (0..<10).map { group in
                CollectionGroup(Array(0..<20).map { "\(group)-\($0)" }) { Label($0) }
                    .id("g\(group)")
                    .header(Label("Group \(group)"))
            })
            .itemSize(10)
            .body
        }

        var patch = renders.render(tree())
        let scrollY = patch.events?[.scrollYChanged] ?? -1

        XCTAssertTrue(renders.fire(rowsOf(patch)[0].events?[.frameChanged] ?? -1,
                                   with: frame(height: 10)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1, with: frame(height: 40)))
        renders.render(tree())

        // Each group is 10 + 20 x 10 = 210 points; 420 is the third group's
        // heading, exactly.
        XCTAssertTrue(renders.fire(scrollY, with: [.number(420)]))
        patch = renders.render(tree())

        XCTAssertTrue(shown(patch).contains("g2/heading"))
        XCTAssertTrue(shown(patch).contains("g1/1-19"), "the margin reaches back into group 1")
        XCTAssertTrue(shown(patch).contains("g2/2-3"))
        XCTAssertFalse(shown(patch).contains("g3/heading"), "and nothing beyond the window")
    }

    // MARK: - Selection

    func testAListNobodyLentABindingHasNoTapAtAll() {
        let renders = Renders()
        let showing = settled(renders, { self.list(100).body })

        XCTAssertNil(rowsOf(showing.patch).first?.events?[.tapped],
                     "a list that is not selectable subscribes nothing")
    }

    func testTappingARowChoosesItAndTappingItAgainClearsIt() {
        let chosen = State<Int?>(nil)
        let renders = Renders()
        let tree = { self.list(100).selection(chosen.projectedValue).body }
        let showing = settled(renders, tree)

        let fifth = rowsOf(showing.patch)[5].events?[.tapped] ?? -1

        XCTAssertTrue(renders.fire(fifth))
        XCTAssertEqual(chosen.wrappedValue, 5)

        XCTAssertTrue(renders.fire(fifth))
        XCTAssertNil(chosen.wrappedValue, "the chosen row tapped again is deselected, as MAUI's is")
    }

    func testAMultipleSelectionTogglesTheRowThatWasTapped() {
        let chosen = State<Set<Int>>([])
        let renders = Renders()
        let tree = { self.list(100).selection(chosen.projectedValue).body }
        let showing = settled(renders, tree)

        let rows = rowsOf(showing.patch)

        XCTAssertTrue(renders.fire(rows[5].events?[.tapped] ?? -1))
        XCTAssertTrue(renders.fire(rows[7].events?[.tapped] ?? -1))
        XCTAssertEqual(chosen.wrappedValue, [5, 7])

        XCTAssertTrue(renders.fire(rows[5].events?[.tapped] ?? -1))
        XCTAssertEqual(chosen.wrappedValue, [7], "the others are kept - one tap moves one row")
    }

    // MARK: - Loading more

    func testTheEndOfTheListAsksForMoreRows() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(60)
                .remainingItemsThreshold(8)
                .onRemainingItemsThresholdReached { asked.wrappedValue += 1 }
                .body
        }

        let showing = settled(renders, tree)
        XCTAssertEqual(asked.wrappedValue, 0, "nobody has scrolled anywhere yet")

        // Row 20 at the top of ten visible ones leaves thirty to go.
        XCTAssertTrue(renders.fire(showing.scrollY, with: [.number(880)]))
        XCTAssertEqual(asked.wrappedValue, 0)

        // Row 45 leaves five, which is inside the threshold.
        XCTAssertTrue(renders.fire(showing.scrollY, with: [.number(1980)]))
        XCTAssertEqual(asked.wrappedValue, 1)
    }

    /// A list that fits in its view entirely has nothing to scroll, so no
    /// scroll is ever reported - and without the second trigger the loading
    /// stalls after the first batch, for ever.
    ///
    /// Measured on Windows 2026-08-13: a maximized window held the whole first
    /// batch of thirty rows, and the Incremental loading sample sat at "Batch
    /// 1" whatever the reader did. The CONTENT's own frame is the second place
    /// the question can become true - it changes as the list grows - so the
    /// list asks again until it outgrows the view or the author's guard stops
    /// it.
    func testAListShorterThanItsViewStillAsksForMore() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(6)
                .remainingItemsThreshold(8)
                .onRemainingItemsThresholdReached { asked.wrappedValue += 1 }
                .body
        }

        // The content's handler is read off the FIRST patch, for the reason
        // `settled` reads the scroller's off it: an event map is sent only when
        // the set of handled events changes.
        var patch = renders.render(tree())
        let content = placer(patch).events?[.frameChanged] ?? -1

        XCTAssertTrue(renders.fire(rowsOf(patch).first?.events?[.frameChanged] ?? -1,
                                   with: frame(height: 44)))
        XCTAssertTrue(renders.fire(patch.events?[.frameChanged] ?? -1,
                                   with: frame(height: 440)))

        patch = renders.render(tree())
        XCTAssertEqual(asked.wrappedValue, 0, "the content has not reported its frame yet")

        XCTAssertTrue(renders.fire(content, with: frame(height: 264)))
        XCTAssertEqual(asked.wrappedValue, 1,
                       "six rows in a view that holds ten - the reader is at the end already, "
                        + "and no scroll will ever say so")
    }

    func testAListThatNobodyAskedToLoadMoreNeverAsks() {
        let asked = State(0)
        let renders = Renders()
        let tree = {
            self.list(60)
                .onRemainingItemsThresholdReached { asked.wrappedValue += 1 }
                .body
        }

        let showing = settled(renders, tree)

        XCTAssertTrue(renders.fire(showing.scrollY, with: [.number(2400)]))
        XCTAssertEqual(asked.wrappedValue, 0,
                       "-1 is MAUI's own default, and it means never")
    }

    // MARK: - What a row keeps

    func testARowsOwnStateBelongsToItsItemWhileTheWindowHoldsIt() {
        struct Row: ContentView {
            let number: Int
            @State var count = 0

            var content: Element {
                Button("\(number): \(count)").onClicked { count += 1 }
            }
        }

        let renders = Renders()
        let tree = { CollectionView(0..<1_000) { Row(number: $0) }.itemSize(44).body }
        let first = renders.render(tree())

        // Press row 2's button, then widen the viewport and scroll a little -
        // both of which leave row 2 inside the window.
        XCTAssertTrue(renders.fire(rowsOf(first)[2].events?[.clicked] ?? -1))
        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(height: 440)))
        XCTAssertTrue(renders.fire(first.events?[.scrollYChanged] ?? -1, with: [.number(44)]))

        let kept = rowsOf(renders.render(tree())).first { $0.id == .manual("2") }

        XCTAssertEqual(kept?.props[.text], .string("2: 1"),
                       "the row stayed in the window, so its own state stayed with it")
    }

    /// The list hears its offset once per ROW rather than once per frame: the
    /// row height is the step the scroller reports at.
    func testTheOffsetIsReportedOncePerRow() {
        let renders = Renders()
        let showing = settled(renders, { CollectionView(0..<1_000) { Label("\($0)") }.body })

        XCTAssertEqual(showing.patch.props[.scrollStep], .number(44))
    }


    /// A run states how long it is, and a view that states a length is placed
    /// in the MIDDLE of whatever room is left over - so a list shorter than
    /// its own scroller would stand in the middle of it with a band of nothing
    /// above and below. It is pinned to the start instead.
    func testTheRunStartsWhereTheScrollerDoes() {
        let renders = Renders()
        let patch = renders.render(list(4).body)

        XCTAssertEqual(placer(patch).props[.verticalOptions],
                       LayoutOptions.start.propValue)

        // And across the axis it fills, which is what gives a row the whole
        // width of the list.
        XCTAssertEqual(placer(patch).props[.horizontalOptions],
                       LayoutOptions.fill.propValue)
    }

    /// And a list that runs across is pinned the other way round.
    func testARunAcrossStartsAtItsLeadingEdge() {
        let renders = Renders()
        let patch = renders.render(list(4).orientation(.horizontal).itemSize(80).body)

        XCTAssertEqual(placer(patch).props[.horizontalOptions],
                       LayoutOptions.start.propValue)
        XCTAssertEqual(placer(patch).props[.verticalOptions],
                       LayoutOptions.fill.propValue)
    }

    // MARK: - Running across

    /// A list told to run across places its items along the OTHER axis, and
    /// each takes the whole of the list's height rather than its width.
    func testRunningAcrossPlacesItemsAlongTheOtherAxis() {
        let renders = Renders()
        let tree = { self.list(1_000).orientation(.horizontal).itemSize(80).body }
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(width: 400)))

        // Described WHOLE rather than as a patch: the geometry was right from
        // the first render - the size was stated, not measured - so a sparse
        // one has nothing to say about it.
        let patch = renders.renderFromScratch(tree())

        // The run is as long as the items are wide, stated across rather than
        // down - and its height is the scroller's own, which a sideways
        // scroller does not give its content by itself.
        XCTAssertEqual(placer(patch).props[.widthRequest], .number(1_000 * 80))
        XCTAssertEqual(placer(patch).props[.heightRequest], .number(240))

        // Item 0 at the beginning, item 1 one item along, both the full height.
        XCTAssertEqual(rowsOf(patch)[0].props[.absoluteLayoutBounds], Rect(0, 0, 80, 1).propValue)
        XCTAssertEqual(rowsOf(patch)[1].props[.absoluteLayoutBounds], Rect(80, 0, 80, 1).propValue)
        XCTAssertEqual(rowsOf(patch)[0].props[.absoluteLayoutFlags],
                       AbsoluteLayoutFlags.heightProportional.propValue)
    }

    /// And it hears the offset the other way: a list that runs across is
    /// scrolled across, and the window follows that.
    func testRunningAcrossFollowsTheOffsetAcross() {
        let renders = Renders()
        let tree = { self.list(1_000).orientation(.horizontal).itemSize(80).body }
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(width: 400)))
        _ = renders.render(tree())

        XCTAssertNil(first.events?[.scrollYChanged], "a list running across listened downwards")
        XCTAssertTrue(renders.fire(first.events?[.scrollXChanged] ?? -1, with: [.number(80 * 20)]))

        // Item 20 is at the edge, and the window is drawn around it.
        XCTAssertEqual(shown(renders.render(tree())).first, "14")
    }

    // MARK: - Resting on an item

    /// A list told to snap gives the scroller a grid of one item, starting
    /// where the items do - which is past whatever header stands before them.
    func testSnappingIsAGridOfOneItem() {
        let renders = Renders()
        let tree = { self.list(1_000).itemSize(44).snapToItem(true).header(Label("head")).body }
        let first = renders.render(tree())

        // The content reports where it sits: 60 down, under the header.
        let placer = first.children.first { $0.type == .absoluteLayout }
        XCTAssertTrue(renders.fire(placer?.events?[.frameChanged] ?? -1, with: frame(y: 60, height: 44_000)))
        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(height: 440)))

        let patch = renders.renderFromScratch(tree())

        XCTAssertEqual(patch.props[.snapInterval], .number(44))
        XCTAssertEqual(patch.props[.snapFrom], .number(60))
    }

    /// A GROUPED list is left alone: a heading is not the size of a row, so
    /// the rows under one stand off any fixed grid.
    func testAGroupedListIsNotSnapped() {
        let renders = Renders()

        let tree = {
            CollectionView(groups: [
                CollectionGroup(["a", "b"]) { Label($0) }.id("one").header(Label("first")),
            ])
            .itemSize(44)
            .snapToItem(true)
            .body
        }

        let first = renders.render(tree())
        XCTAssertTrue(renders.fire(first.events?[.frameChanged] ?? -1, with: frame(height: 440)))

        XCTAssertNil(renders.renderFromScratch(tree()).props[.snapInterval])
    }

    /// A list that says nothing about resting says nothing to the scroller.
    func testAListThatDoesNotSnapWritesNoGrid() {
        let renders = Renders()
        _ = settled(renders, { self.list(100).body })

        XCTAssertNil(renders.renderFromScratch(self.list(100).body).props[.snapInterval])
    }
}