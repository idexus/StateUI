// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `if`, `if/else` and `for` inside a builder, and what the differ makes of them.
//
// Every case here was a bug before the builder wrote down WHERE each view was
// written: flattening an `if` into a list leaves nothing but the index, and an
// index is not identity once the number of children can change. See
// Views/ViewBuilder.swift.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class BuilderTests: XCTestCase {
    // MARK: - Reading a patch

    /// The first patch describing an element of this type, at any depth.
    private func patch(_ patch: Patch, forType type: NodeType) -> Patch? {
        if patch.type == type { return patch }

        for child in patch.children {
            if let hit = self.patch(child, forType: type) { return hit }
        }

        return nil
    }

    /// Every element the patch mentions, at any depth.
    private func mentioned(_ patch: Patch) -> [Patch] {
        [patch] + patch.children.flatMap { mentioned($0) }
    }

    // MARK: - An `if` beside other views

    /// The one that started this: an `if` with no `else` moved its siblings.
    ///
    /// Signed out, the Entry is child 0; signed in, child 0 is the Label. By
    /// index that reads as "the Entry became a Label", which is a changed type
    /// and so a REPLACED control - the search box was rebuilt on every toggle,
    /// losing its focus, its caret and its scroll.
    func testAConditionalDoesNotMoveTheViewsAfterIt() {
        func tree(signedIn: Bool) -> Node {
            VStack {
                if signedIn {
                    Label("Welcome")
                }

                Entry("search")
            }
            .body
        }

        let renders = Renders()

        let first = renders.render(tree(signedIn: false))
        let entry = try? XCTUnwrap(patch(first, forType: "Entry")?.id)

        let second = renders.render(tree(signedIn: true))

        XCTAssertTrue(second.children.map(\.id).contains(entry ?? .auto(-1)),
                      "nothing left the tree - the Entry is still in the list")

        // The Entry moved down one place, so it is mentioned; what matters is
        // that it is the SAME element and was not rebuilt.
        if let moved = patch(second, forType: "Entry") {
            XCTAssertEqual(moved.id, entry, "the Entry was handed another element's identity")
            XCTAssertFalse(moved.replace, "the Entry was rebuilt by an `if` that is not about it")
            XCTAssertNil(moved.props["text"], "the Entry's own properties were re-sent for no reason")
        }

        // And back again.
        let third = renders.render(tree(signedIn: false))
        XCTAssertEqual(patch(third, forType: "Entry")?.id ?? entry, entry)
    }

    /// A handler belongs to the element, so a conditional above it must not
    /// take it away. The id is what C# quotes back; a new one means the button
    /// C# is showing reports an id nothing answers to.
    func testAViewAfterAConditionalKeepsItsHandler() {
        let taps = State(0)

        func tree(showing: Bool) -> Node {
            VStack {
                if showing {
                    Label("note")
                }

                Button("Go").onClicked { taps.wrappedValue += 1 }
            }
            .body
        }

        let renders = Renders()

        let first = renders.render(tree(showing: false))
        let clicked = patch(first, forType: "Button")?.events?["clicked"]
        XCTAssertNotNil(clicked)

        renders.render(tree(showing: true))
        renders.render(tree(showing: false))

        XCTAssertTrue(renders.fire(clicked ?? -1), "the handler id stopped answering")
        XCTAssertEqual(taps.wrappedValue, 1)
    }

    // MARK: - The two branches of an if/else

    /// Two branches are two elements, even when they build the same control.
    ///
    /// Read as ONE Entry that merely changes its text,
    /// `if editing { Entry($name) } else { Entry($nickname) }` would keep the
    /// caret put across what the author wrote as a switch between two
    /// different fields.
    func testTheTwoBranchesOfAnIfAreDifferentElements() {
        func tree(editing: Bool) -> Node {
            VStack {
                if editing {
                    Entry("name")
                } else {
                    Entry("nickname")
                }
            }
            .body
        }

        let renders = Renders()

        let first = renders.render(tree(editing: true))
        let name = patch(first, forType: "Entry")?.id

        let second = renders.render(tree(editing: false))
        let nickname = patch(second, forType: "Entry")?.id

        XCTAssertNotNil(name)
        XCTAssertNotNil(nickname)
        XCTAssertNotEqual(name, nickname, "both branches were given one control to share")
        XCTAssertFalse(second.children.map(\.id).contains(name ?? .auto(-1)),
                       "the branch that left took its element with it")
    }

    /// Going back to a branch that was shown before starts it afresh rather
    /// than digging up what it left behind - which is what "deterministic"
    /// means here: the same tree describes the same controls however it was
    /// arrived at.
    func testABranchComesBackWholeRatherThanPatched() {
        func tree(showing: Bool) -> Node {
            Grid {
                Label("tabs").gridRow(0)

                if showing {
                    Border {
                        BoxView(Color("#512BD4")).cornerRadius(10)
                    }
                    .gridRow(1)
                } else {
                    ScrollView {
                        Label("code")
                    }
                    .gridRow(1)
                }
            }
            .body
        }

        let renders = Renders()

        renders.render(tree(showing: true))
        renders.render(tree(showing: false))
        let third = renders.render(tree(showing: true))

        // The header is not part of the conditional and must not be touched.
        XCTAssertNil(patch(third, forType: "Label").flatMap { $0.props["text"] },
                     "a view beside the conditional was re-sent")

        let box = try? XCTUnwrap(patch(third, forType: "BoxView"))
        XCTAssertNotNil(box?.props["color"], "the branch came back without its colour")
        XCTAssertNotNil(box?.props["cornerRadius"], "the branch came back without its shape")
    }

    // MARK: - A loop, and a conditional inside one

    /// The item is the row's identity - stamped as the id an author would
    /// have written - and the `id:` form names which part of the item it is.
    func testAForEachRowIsIdentifiedByItsItem() {
        let tree = VStack {
            ForEach(["left", "right"]) { Label($0) }
            ForEach([(name: "a", n: 1), (name: "b", n: 2)], id: \.name) { Label($0.name) }
        }
        .body

        XCTAssertEqual(tree.children.map(\.id), ["left", "right", "a", "b"])

        // A written `.id()` wins over the item.
        let named = VStack {
            ForEach(["x"]) { Label($0).id("mine") }
        }
        .body

        XCTAssertEqual(named.children.first?.id, "mine")
    }

    /// A reorder MOVES the rows: each element follows its item, so what the
    /// host hears is the ARRANGED list in its new order - every row a stub,
    /// none of them rebuilt.
    func testAForEachRowFollowsItsItemThroughAReorder() {
        func tree(_ items: [String]) -> Node {
            VStack {
                ForEach(items) { item in
                    Label(item)
                }
            }
            .body
        }

        let renders = Renders()

        let first = renders.render(tree(["a", "b", "c"]))
        let ids = Set(first.children.map { $0.id })

        let second = renders.render(tree(["c", "a", "b"]))

        XCTAssertTrue(second.arranged, "a reorder must send the arranged list")
        XCTAssertEqual(second.children.count, 3, "the arranged list is the whole list")

        for child in second.children {
            XCTAssertTrue(ids.contains(child.id), "a moved row was rebuilt as a new element")
            XCTAssertTrue(child.props.isEmpty, "a row that only moved re-sent its properties")
        }
    }

    /// The case written out in full: eleven rows, each choosing a control.
    ///
    /// Turn 3 stops being the chosen one and turn 7 becomes it. A ForEach row
    /// is identified by its ITEM, so both keep their identity and are
    /// REPLACED in place for their new kind - and nothing else may move.
    func testAConditionalInsideAForEachKeepsEachRowApart() {
        func tree(chosen: Int) -> Node {
            VStack {
                ForEach(0...10) { turn in
                    if turn == chosen {
                        return Label("turn \(turn)")
                    } else {
                        return BoxView(Color("#C8C8C8"))
                    }
                }
            }
            .body
        }

        let renders = Renders()

        let first = renders.render(tree(chosen: 3))
        XCTAssertEqual(first.children.count, 11)

        let second = renders.render(tree(chosen: 7))

        // Two turns changed their minds and NOTHING was added, removed or
        // moved - so the message is SPARSE: the two elements that changed
        // kind, each found by its identity, and not a word about the other
        // nine, which is what says they were left alone.
        XCTAssertFalse(second.arranged, "nothing moved, so the arrangement did not change")
        XCTAssertEqual(second.children.count, 2,
                       "a loop of 11 reported \(second.children.count) changes for a swap of 2")

        let types = second.children.map { $0.type }.sorted()
        XCTAssertEqual(types, ["BoxView", "Label"])

        // The chosen one is turn 7's, and it is the element that has stood
        // at turn 7's place since the first render.
        let label = second.children.first { $0.type == "Label" }
        XCTAssertEqual(label?.id, first.children[7].id, "the label is not turn 7's element")
        XCTAssertEqual(label?.props["text"], .string("turn 7"))
    }

    /// A loop that gets longer leaves the rows it already had alone.
    func testAForEachThatGrowsKeepsTheRowsItHad() {
        func tree(turns: Int) -> Node {
            VStack {
                ForEach(0..<turns) { turn in
                    Label("turn \(turn)")
                }
            }
            .body
        }

        let renders = Renders()

        let first = renders.render(tree(turns: 3))
        let ids = first.children.map { $0.id }

        let second = renders.render(tree(turns: 5))

        XCTAssertTrue(second.arranged)
        XCTAssertEqual(second.children.count, 5, "the complete list, in order")
        XCTAssertEqual(second.children.filter { !$0.isEmpty }.count, 2,
                       "the turns that did not change were re-sent")

        let third = renders.render(tree(turns: 3))
        XCTAssertTrue(third.arranged)
        XCTAssertEqual(third.children.count, 3)
        XCTAssertTrue(third.children.allSatisfy { $0.isEmpty },
                      "the three that stayed are stubs - the two that left are simply not named")

        // And the three that were there all along are the same three.
        let fourth = renders.render(tree(turns: 3))
        XCTAssertTrue(fourth.isEmpty, "rendering the same tree twice reported a change")
        XCTAssertEqual(ids.count, 3)
    }

    // MARK: - The other two ways to be identified

    /// `.id()` still wins, and still finds the element wherever it moved to.
    func testAnIdOfTheAuthorsWinsOverThePath() {
        func tree(showing: Bool, first: Bool) -> Node {
            VStack {
                if showing {
                    Label("note")
                }

                if first {
                    Label("a").id("row")
                } else {
                    Label("b").id("row")
                }
            }
            .body
        }

        let renders = Renders()

        renders.render(tree(showing: false, first: true))

        // A different BRANCH, but the author named both the same thing - so it
        // is one element that changed its text, which is what he asked for.
        let second = renders.render(tree(showing: true, first: false))

        XCTAssertTrue(second.arranged, "the note arrived, so the whole arrangement is said")

        let row = try? XCTUnwrap(second.children.first { $0.id == .manual("row") })
        XCTAssertEqual(row?.props["text"], .string("b"))
        XCTAssertEqual(row?.replace, false)
    }

    /// A child list built by hand - which is what a page's own furniture is -
    /// is still matched by position, and is not confused by the built ones
    /// beside it.
    func testAHandBuiltChildListIsStillMatchedByPosition() {
        func tree(_ text: String) -> Node {
            Node(
                type: "VerticalStackLayout",
                children: [
                    Node(type: "Label", props: ["text": .string(text)]),
                    Node(type: "Entry", props: ["text": .string("kept")]),
                ])
        }

        let renders = Renders()

        let first = renders.render(tree("one"))
        let ids = first.children.map { $0.id }

        let second = renders.render(tree("two"))

        XCTAssertEqual(second.children.count, 1)
        XCTAssertEqual(second.children.first?.id, ids.first)
        XCTAssertEqual(second.children.first?.props["text"], .string("two"))
        XCTAssertFalse(second.arranged)
    }

    // MARK: - What the host is told

    /// The path is the differ's business and nobody else's.
    ///
    /// It is not an identity C# can use - two renders of a memoized subtree
    /// would report the same path for elements the host has under different
    /// ids - so it stays on this side, and the wire is unchanged by all of it.
    func testThePathNeverReachesTheHost() {
        let tree = VStack {
            if true {
                Label("shown")
            }

            ForEach(0..<2) { turn in
                Label("turn \(turn)")
            }
        }
        .body

        let bytes = Wire.encode(Renders().render(tree), generation: 1, dictionary: WireDictionary())
        let dump = WireProbe.dumpMessage(bytes, names: WireNames())

        XCTAssertFalse(dump.contains("key:"), "the builder's path was sent to the host:\n\(dump)")
        XCTAssertTrue(dump.contains("\"turn 1\""), dump)
    }
}
