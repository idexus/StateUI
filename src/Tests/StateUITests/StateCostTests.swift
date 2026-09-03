// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StateUI

/// What declaring a piece of state costs.
///
/// A view is a value rebuilt on every render, so the expression beside every
/// `@State` declaration is written where a render passes through it. These
/// hold the rule that makes that safe: the expression is run when the value is
/// first WANTED, which for a box that adopts its predecessor's storage - every
/// render after the first - is never.
final class StateCostTests: XCTestCase {
    /// How many times the initial value has been worked out.
    nonisolated(unsafe) static var made = 0

    /// An initial value that says when it was worked out.
    private static func counted(_ value: Int = 7) -> Int {
        made += 1
        return value
    }

    override func setUp() {
        super.setUp()
        Self.made = 0
    }

    /// The rule itself, at its smallest.
    func testAnInitialValueIsNotWorkedOutUntilItIsWanted() {
        let state = State(Self.counted())

        XCTAssertEqual(Self.made, 0, "declaring state works nothing out")

        XCTAssertEqual(state.wrappedValue, 7, "and the value is what was written")
        XCTAssertEqual(Self.made, 1, "worked out by the read that wanted it")

        _ = state.wrappedValue
        XCTAssertEqual(Self.made, 1, "and kept, rather than worked out again")
    }

    /// A view NOBODY describes never works its state out at all - which is
    /// what stops one expensive view from costing every render of an
    /// application that merely holds a list of them.
    func testAViewNobodyDescribesWorksNothingOut() {
        struct Costly: ContentView {
            @State private var items = StateCostTests.counted()

            var content: Element { Label("\(items)") }
        }

        _ = Costly()
        _ = Costly()

        XCTAssertEqual(Self.made, 0, "constructed, never described, never paid for")
    }

    /// THE RENDER LOOP, which is where this is worth anything: a rebuilt view
    /// hands its fresh box the storage the old one held, so the expression
    /// beside the declaration answers for the FIRST render and no other.
    func testAnAdoptedStateWorksItsInitialValueOutOnce() {
        // A ContentView, because that is what carries state across renders:
        // the differ hands a rebuilt view's boxes the storage their
        // predecessors held, and a plain Element has no such placeholder.
        struct Costly: ContentView {
            let shown: Int
            @State private var items = StateCostTests.counted()

            var content: Element {
                VStack {
                    Label("shown \(shown)")
                    Label("items \(items)")
                }
            }
        }

        struct Page: Element {
            let shown: Int

            var body: Node { VStack { Costly(shown: shown) }.body }
        }

        let renders = Renders()

        _ = renders.render(Page(shown: 1).body)
        _ = renders.render(Page(shown: 2).body)
        _ = renders.render(Page(shown: 3).body)

        XCTAssertEqual(Self.made, 1, "one storage, one initial value")
    }

    /// A value written before anybody read it stands, and the expression it
    /// replaces is never run - a default is what to hold when nothing else
    /// says, and something else has said.
    func testAWriteBeforeAnyReadReplacesTheInitialValue() {
        let state = State(Self.counted())

        state.wrappedValue = 3

        XCTAssertEqual(Self.made, 0, "nothing wanted the value that was replaced")
        XCTAssertEqual(state.wrappedValue, 3, "and the write is what stands")
        XCTAssertEqual(Self.made, 0, "still nothing to work out")
    }

    /// Changing a value nobody has read works the initial one out first, so
    /// the change is applied to what the author wrote rather than to nothing.
    func testUpdatingWorksTheInitialValueOutFirst() {
        let state = State(Self.counted(10))

        state.update { $0 + 1 }

        XCTAssertEqual(state.wrappedValue, 11, "the change landed on the default")
        XCTAssertEqual(Self.made, 1, "which had to be worked out to change it")
    }

    /// A RUN OF ITEMS IS DATA, AND THE WALK MUST NOT DESCEND INTO IT.
    ///
    /// The walk that pairs a rebuilt view's `@State` with the storage it had
    /// last render recurses through everything a view stores, looking for the
    /// state a nested view owns. A list-shaped view stores its ITEMS, which
    /// are records rather than views - so every field of every item would be
    /// visited on every render, to find state that is not there. Each of the
    /// three holds its items behind a reference, which is where the walk
    /// stops.
    ///
    /// ASKED AS A COMPARISON, because these views have state of their own and
    /// the number of boxes they carry is theirs to change: the same view over
    /// items that DO carry state and over items that do not must answer the
    /// same count, and does so only while the items are out of the walk.
    func testAViewOverARunHoldsItsItemsOutOfTheStateWalk() {
        struct Carrying {
            let name: String
            let held = State(0)
        }

        struct Plain {
            let name: String
        }

        let carrying = [Carrying(name: "a"), Carrying(name: "b"), Carrying(name: "c")]
        let plain = [Plain(name: "a"), Plain(name: "b"), Plain(name: "c")]

        XCTAssertEqual(
            stateParts(in: carrying).boxes.count, 3,
            "the items really do carry state, or this test proves nothing")
        XCTAssertEqual(stateParts(in: plain).boxes.count, 0)

        func placed<Items: RandomAccessCollection>(
            _ items: Items,
            _ name: KeyPath<Items.Element, String>
        ) -> Int {
            stateParts(in: PlacedLayout(items, id: name) { item in
                Label(item[keyPath: name])
            }).boxes.count
        }

        XCTAssertEqual(
            placed(carrying, \Carrying.name), placed(plain, \Plain.name),
            "PlacedLayout holds its items behind a reference")

        func listed<Items: RandomAccessCollection>(
            _ items: Items,
            _ name: KeyPath<Items.Element, String>
        ) -> Int {
            stateParts(in: CollectionView(items, id: name) { item in
                Label(item[keyPath: name])
            }).boxes.count
        }

        XCTAssertEqual(
            listed(carrying, \Carrying.name), listed(plain, \Plain.name),
            "CollectionView holds its items behind a reference")

        func run<Items: RandomAccessCollection>(
            _ items: Items,
            _ name: KeyPath<Items.Element, String>
        ) -> Int {
            stateParts(in: GalleryView(items, id: name) { item in
                Label(item[keyPath: name])
            }).boxes.count
        }

        XCTAssertEqual(
            run(carrying, \Carrying.name), run(plain, \Plain.name),
            "GalleryView holds its items behind a reference")
    }

    /// A binding reads through to the same storage, so borrowing state is one
    /// of the things that WANTS the value.
    func testABindingWorksTheInitialValueOut() {
        let state = State(Self.counted(4))
        let borrowed = state.projectedValue

        XCTAssertEqual(Self.made, 0, "lending works nothing out")
        XCTAssertEqual(borrowed.wrappedValue, 4, "and reads what was written")
        XCTAssertEqual(Self.made, 1)
    }
}
