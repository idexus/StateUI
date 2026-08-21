// What a render says, and - more often - what it does not.

import XCTest
@testable import StateUI

final class DiffTests: XCTestCase {
    func testFirstRenderDescribesEverything() {
        let renders = Renders()

        let patch = renders.render(stack([label("one", id: "a")], id: "root"))

        XCTAssertEqual(patch.props["spacing"], nil)
        XCTAssertTrue(patch.arranged, "a first render says how the children stand")
        XCTAssertEqual(patch.children.count, 1)
        XCTAssertEqual(patch.child("a")?.props["text"], .string("one"))
    }

    func testAnUnchangedTreeSaysNothing() {
        let renders = Renders()
        let tree = stack([label("one", id: "a")], id: "root")

        renders.render(tree)
        let patch = renders.render(tree)

        XCTAssertTrue(patch.isEmpty, "an unchanged tree should produce an empty patch")
    }

    func testOnlyTheChangedPropertyIsSent() {
        let renders = Renders()

        renders.render(stack([
            label("one", id: "a"),
            label("two", id: "b"),
        ], id: "root"))

        let patch = renders.render(stack([
            label("ONE", id: "a"),
            label("two", id: "b"),
        ], id: "root"))

        XCTAssertEqual(patch.children.count, 1, "only the label that changed")
        XCTAssertEqual(patch.child("a")?.props, ["text": .string("ONE")])
        XCTAssertNil(patch.child("b"))
        XCTAssertFalse(patch.arranged, "the arrangement did not change")
    }

    /// The runs of a formatted label are a list like any other, so a change to
    /// one of them carries THAT one.
    ///
    /// This is the half of the promise this side makes; the host's half is
    /// keeping the collection rather than rebuilding it, which
    /// `APatchAboutOneRunLeavesTheOtherRunsAlone` pins. A message that repeated
    /// every run on every render would work and would send a whole highlighted
    /// code block each time one token changed colour.
    func testAChangedRunCarriesThatRunAlone() throws {
        let renders = Renders()

        func code(_ name: Color) -> Node {
            Label()
                .formattedText {
                    TextSpan("let ").textColor(.purple)
                    TextSpan("counter").textColor(name)
                }
                .body
        }

        renders.render(code(.steelBlue))
        let patch = renders.render(code(.firebrick))

        // The FormattedString is the label's one child, and it is on the path
        // to the run rather than a thing that changed itself.
        let runs = try XCTUnwrap(patch.children.first)
        XCTAssertEqual(runs.type, "FormattedString")
        XCTAssertTrue(runs.props.isEmpty)
        XCTAssertFalse(runs.arranged, "the arrangement of the runs did not change")

        let changed = try XCTUnwrap(runs.children.first)
        XCTAssertEqual(runs.children.count, 1, "only the run whose colour moved")
        XCTAssertEqual(changed.type, "Span")
        XCTAssertEqual(changed.props, ["textColor": Color("#B22222").propValue],
                       "the colour alone - not the text it still shows")
    }

    /// And a run that leaves is named, so the host can drop that one and keep
    /// the rest: position cannot say who went.
    func testARunThatLeavesIsNamed() throws {
        let renders = Renders()

        func line(_ sold: Bool) -> Node {
            Label()
                .formattedText {
                    TextSpan("Sold")

                    if sold {
                        TextSpan(" out")
                    }
                }
                .body
        }

        renders.render(line(true))
        let patch = renders.render(line(false))

        let runs = try XCTUnwrap(patch.children.first)

        XCTAssertTrue(runs.arranged, "a run left, so the whole arrangement is said")
        XCTAssertEqual(runs.children.count, 1, "and the one run left is all it lists")
        XCTAssertTrue(runs.children[0].props.isEmpty,
                      "the run that stayed rides as a stub with nothing to say")
    }

    func testALostPropertyIsClearedRatherThanReplacingTheControl() {
        let renders = Renders()

        renders.render(Node(type: "Label", id: "a", props: [
            "text": .string("one"),
            "fontSize": .number(20),
        ]))

        let patch = renders.render(Node(type: "Label", id: "a", props: ["text": .string("one")]))

        XCTAssertFalse(patch.replace, "the control stays, with its handlers and everything under it")
        XCTAssertEqual(patch.cleared, ["fontSize"], "and the property that went away is named")
        XCTAssertTrue(patch.props.isEmpty, "nothing else changed, so nothing else is said")
    }

    func testAClearingPatchIsWorthSendingOnItsOwn() {
        let renders = Renders()

        renders.render(stack([
            Node(type: "Label", id: "a", props: ["fontSize": .number(20)]),
        ]))

        let patch = renders.render(stack([Node(type: "Label", id: "a")]))

        // The label says nothing except that a property is gone. A patch is
        // dropped when it is empty, and one that clears is not empty - without
        // that the message would leave and the size would stay on the control.
        let label = patch.children.first

        XCTAssertEqual(label?.cleared, ["fontSize"])
    }

    func testAPropertyWithNoDefaultToGoBackToStillReplacesTheControl() {
        let renders = Renders()

        renders.render(Node(type: "Picker", id: "a", props: [
            "title": .string("pick"),
            "itemsSource": .values([.string("one"), .string("two")]),
        ]))

        let patch = renders.render(Node(type: "Picker", id: "a", props: ["title": .string("pick")]))

        // A list's items are data: MAUI has no default to put back, so the
        // only honest answer is the control again. See Prop.notCleared.
        XCTAssertTrue(patch.replace, "nothing can clear items away")
        XCTAssertTrue(patch.cleared.isEmpty, "a complete node has nothing to clear")
        XCTAssertEqual(patch.props, ["title": .string("pick")], "and it comes back complete")
    }

    func testAChangedTypeReplacesTheControl() {
        let renders = Renders()

        renders.render(Node(type: "Label", id: "a", props: ["text": .string("one")]))
        let patch = renders.render(Node(type: "Button", id: "a", props: ["text": .string("one")]))

        XCTAssertTrue(patch.replace)
        XCTAssertEqual(patch.type, "Button")
    }

    func testKeyedChildrenMoveRatherThanRebuild() {
        let renders = Renders()

        renders.render(stack([
            label("a", id: "a"),
            label("b", id: "b"),
        ], id: "root"))

        // One inserted at the top: the other two only moved.
        let patch = renders.render(stack([
            label("z", id: "z"),
            label("a", id: "a"),
            label("b", id: "b"),
        ], id: "root"))

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.map(\.id),
                       [.manual("z"), .manual("a"), .manual("b")],
                       "the list itself is the order")
        XCTAssertEqual(patch.child("z")?.props["text"], .string("z"), "the new one arrives complete")
        XCTAssertTrue(patch.child("a")!.props.isEmpty, "a row that only moved rides as a stub")
        XCTAssertTrue(patch.child("b")!.props.isEmpty)
    }

    func testRemovedChildrenAreNamed() {
        let renders = Renders()

        renders.render(stack([
            label("a", id: "a"),
            label("b", id: "b"),
            label("c", id: "c"),
        ], id: "root"))

        let patch = renders.render(stack([
            label("a", id: "a"),
            label("c", id: "c"),
        ], id: "root"))

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.map(\.id), [.manual("a"), .manual("c")],
                       "who left is whoever the complete list no longer names")
        XCTAssertNil(patch.child("b"))
        XCTAssertTrue(patch.child("a")!.props.isEmpty, "the ones that stayed are stubs")
    }

    func testUnkeyedChildrenAreMatchedByPosition() {
        let renders = Renders()

        renders.render(stack([label("a"), label("b")], id: "root"))

        // Nothing says who these are, so the first is still the first: inserting
        // at the top rewrites every row rather than moving it.
        let patch = renders.render(stack([label("z"), label("a"), label("b")], id: "root"))

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.count, 3, "every row had to be told something")
        XCTAssertEqual(patch.children[0].props["text"], .string("z"))
    }

    func testHandlerIdsSurviveRenders() {
        let renders = Renders()
        var taps = 0

        func tree(_ text: String) -> Node {
            Node(type: "Button", id: "b",
                 props: ["text": .string(text)],
                 events: ["clicked": { taps += 1 }])
        }

        let first = renders.render(tree("one"))
        let id = first.events?["clicked"]
        XCTAssertNotNil(id)

        let second = renders.render(tree("two"))
        XCTAssertNil(second.events, "the set of events did not change, so nothing is sent")

        XCTAssertTrue(renders.fire(id!), "the id C# is holding still resolves")
        XCTAssertEqual(taps, 1)
    }

    /// An element that SURVIVES but loses its last handler carries an EMPTY
    /// event set - not nothing. An empty set is "clear what you had"; nothing
    /// at all would read as "unchanged", and C# would keep resolving a gesture
    /// to a handler this side has forgotten. See Core/Wire.swift.
    func testAnElementThatLosesItsLastHandlerCarriesAnEmptySet() {
        let renders = Renders()

        func tree(_ withHandler: Bool) -> Node {
            var node = Node(type: "Button", id: "b", props: ["text": .string("go")])
            if withHandler { node.events["clicked"] = {} }
            return node
        }

        let first = renders.render(tree(true))
        XCTAssertNotNil(first.events?["clicked"])

        let second = renders.render(tree(false))

        XCTAssertEqual(second.events, [:], "the emptied set crosses, so C# clears its map")
    }

    /// And an element that never had a handler says NOTHING about events, on a
    /// first render as much as on a later one - the empty set is a delta, not a
    /// thing every eventless control repeats.
    func testAnEventlessElementSaysNothingAboutEvents() {
        let renders = Renders()

        let first = renders.render(label("plain", id: "a"))
        XCTAssertNil(first.events, "a fresh eventless element carries no event field")

        let second = renders.render(label("still", id: "a"))
        XCTAssertNil(second.events)
    }

    func testHandlersOfRemovedElementsStopResolving() {
        let renders = Renders()

        let first = renders.render(stack([
            Node(type: "Button", id: "b", events: ["clicked": {}]),
        ], id: "root"))

        let id = first.child("b")!.events!["clicked"]!

        renders.render(stack([], id: "root"))

        XCTAssertFalse(renders.fire(id), "an element that left takes its handler with it")
    }

    /// Three events on one element get their ids in name order, not in whatever
    /// order a Dictionary happens to be in this time.
    ///
    /// Swift seeds its hashing per process, so without this the same tree hands
    /// out different ids on every run. Nothing breaks either way - the ids
    /// travel with the element - but two runs of one tree stop being
    /// comparable, and a fixture cannot be written down at all.
    func testHandlerIdsAreAssignedInNameOrder() {
        let renders = Renders()

        let patch = renders.render(Node(type: "Button", id: "b", events: [
            "released": {}, "clicked": {}, "pressed": {},
        ]))

        let events = patch.events ?? [:]

        XCTAssertEqual(events["clicked"], 1)
        XCTAssertEqual(events["pressed"], 2)
        XCTAssertEqual(events["released"], 3)
    }

    func testAStaleBaselineGetsTheWholeTree() {
        let renders = Renders()
        let tree = stack([label("one", id: "a")], id: "root")

        renders.render(tree)

        // What the host gets when it could not apply the last message.
        let patch = renders.renderFromScratch(tree)

        XCTAssertFalse(patch.isEmpty)
        XCTAssertTrue(patch.arranged, "a resync says how the children stand")
        XCTAssertEqual(patch.children.count, 1)
        XCTAssertEqual(patch.child("a")?.props["text"], .string("one"))
    }

    // ---- A resync changes the message, not who anything is -----------------
    //
    // The complete tree is reconciled against the one this side is showing,
    // never against nothing. Reconciling against nothing - which is what a
    // resync did first - reset every @State to its initial value and left the
    // whole previous handler registry live forever, with stale controls still
    // able to reach the leaked closures.

    /// The same element keeps the same identity through a resync, so the
    /// control showing it is reused rather than replaced - focus, caret and
    /// scroll position live in the control.
    func testAResyncKeepsAnAutomaticIdentity() {
        let renders = Renders()
        let tree = stack([label("one")], id: "root")

        let first = renders.render(tree)
        let resync = renders.renderFromScratch(tree)

        XCTAssertEqual(resync.children.first?.id, first.children.first?.id)
        XCTAssertEqual(resync.children.first?.replace, false)
    }

    /// A handler id outlives a resync the way it outlives any other render, so
    /// an event from a control the host is re-applying still reaches its
    /// closure.
    func testAResyncKeepsTheHandlerOfAnElementStillThere() {
        let renders = Renders()
        let taps = State(0)
        let tree = { stack([button("go", id: "a") { taps.wrappedValue += 1 }], id: "root") }

        let first = renders.render(tree())
        let id = first.child("a")?.events?["clicked"] ?? -1

        let resync = renders.renderFromScratch(tree())

        XCTAssertEqual(resync.child("a")?.events?["clicked"], id)
        XCTAssertTrue(renders.fire(id))
        XCTAssertEqual(taps.wrappedValue, 1)
    }

    /// And one that left in the resync takes its handler with it - the leak was
    /// exactly here, every id of the previous tree staying live forever.
    func testAResyncForgetsWhatLeftWithIt() {
        let renders = Renders()
        let taps = State(0)

        let first = renders.render(stack([
            button("a", id: "a") { taps.wrappedValue += 1 },
            button("b", id: "b") { taps.wrappedValue += 1 },
        ], id: "root"))

        let gone = first.child("b")?.events?["clicked"] ?? -1

        renders.renderFromScratch(stack([
            button("a", id: "a") { taps.wrappedValue += 1 },
        ], id: "root"))

        XCTAssertFalse(renders.fire(gone))
    }

    /// A resync leaves the differ agreeing with itself: the next ordinary
    /// render has nothing to say.
    func testARenderAfterAResyncSendsNothingNew() {
        let renders = Renders()
        let tree = stack([label("one", id: "a")], id: "root")

        renders.render(tree)
        renders.renderFromScratch(tree)

        XCTAssertTrue(renders.render(tree).isEmpty)
    }
}

/// A view that owns a counter, for the test that a resync does not take it.
private struct Tally: ContentView {
    @State var count = 0

    var content: Element {
        Button("Count: \(count)").onClicked { count += 1 }
    }
}

extension DiffTests {
    /// The bug that made a resync expensive to be wrong about: reconciling
    /// against nothing skipped state adoption, and every counter, draft and
    /// toggle snapped back to its initial value.
    func testAResyncKeepsAViewsState() {
        let renders = Renders()

        let first = renders.render(Tally().body)
        renders.fire(first.events?["clicked"] ?? -1)

        let resync = renders.renderFromScratch(Tally().body)

        XCTAssertEqual(
            resync.props["text"], .string("Count: 1"),
            "a resync describes the tree as it IS - state included")

        renders.fire(resync.events?["clicked"] ?? -1)

        XCTAssertEqual(
            renders.render(Tally().body).props["text"], .string("Count: 2"),
            "and the handler kept writing to the storage the view still reads")
    }
}


extension DiffTests {
    /// Two siblings written with the same `.id()` are a mistake, but a STABLE
    /// one: the repeat keeps its own identity every render rather than being
    /// handed a fresh one and rebuilt each time. So a change to the FIRST does
    /// not resend the whole arrangement, and the second's control survives.
    func testADuplicateIdIsStableAcrossRenders() {
        let renders = Renders()

        func tree(_ first: String) -> Node {
            stack([label(first, id: "dup"), label("second", id: "dup")], id: "root")
        }

        let firstPatch = renders.render(tree("one"))
        XCTAssertTrue(firstPatch.arranged, "the first render says how they stand")
        XCTAssertEqual(firstPatch.children.count, 2, "both are described")

        let secondPatch = renders.render(tree("ONE"))

        XCTAssertFalse(
            secondPatch.arranged,
            "the arrangement did not change - the repeat kept its identity")
        XCTAssertEqual(
            secondPatch.children.compactMap { $0.props["text"]?.string }, ["ONE"],
            "only the label that changed is sent, the repeat left alone")
    }

    /// The two carry DIFFERENT identities on the wire, so C# keeps them as two
    /// controls: the second's is the id with an occurrence number behind it.
    func testTwoDuplicatesAreTwoIdentities() {
        let renders = Renders()

        let patch = renders.render(
            stack([label("a", id: "dup"), label("b", id: "dup")], id: "root"))

        let ids = patch.children.map { $0.id }
        XCTAssertEqual(ids.count, 2)
        XCTAssertNotEqual(ids[0], ids[1], "one identity is not given to two controls")
    }
}
