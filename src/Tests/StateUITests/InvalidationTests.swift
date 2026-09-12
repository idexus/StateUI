// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A render that knows WHICH state changed rebuilds the views that read it and
// leaves the rest of the tree alone. These count the builds, because a body
// that runs when it should not - and one that fails to run when it should -
// look identical on the wire.
//
// The mechanism under test is in Core/Invalidation.swift (reads), Renderer
// (changes and the choice of path) and Differ.revisit (the walk). The promise
// the whole thing rests on: a view is built again when its own recorded reads
// moved OR when its parent was built again - never skipped on a guess.

import XCTest
import StateUIWireProbe
@testable import StateUI

/// Counts how often a body ran. A class, so the Mirror walk that collects
/// state boxes leaves it alone.
private final class Builds {
    var count = 0
}

/// A composed view reading ONE of two states it is handed, by a decision the
/// test flips - the `decision ? first : second` shape.
private final class Chooses: ContentView {
    let first: State<Int>
    let second: State<Int>
    @State var decision = true

    init(first: State<Int>, second: State<Int>) {
        self.first = first
        self.second = second
    }

    var content: any View {
        ModifiedContent(node: label("\(decision ? first.get() : second.get())"))
    }
}

/// A composed view that reads a state it is HANDED - a live reader of it for
/// as long as it stands in a tree.
private struct Shows: ContentView {
    let state: State<Int>

    var content: any View {
        ModifiedContent(node: label("\(state.get())"))
    }
}

/// A composed view that reads its own `@State` and counts its builds.
private struct Tile: ContentView {
    let builds: Builds
    let tag: String
    @State var n = 0

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: label("\(tag)\(n)"))
    }
}

/// A parent whose body builds a Tile afresh each time it runs.
private struct Panel: ContentView {
    let builds: Builds
    let child: Builds
    @State var title = "t"

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: stack([label(title), Tile(builds: child, tag: "c").body]))
    }
}

/// Owns a flag it never reads - only lends. The reader is what depends on it.
/// A parent that hands its own state to the child as a plain value.
private struct Handing: ContentView {
    let builds: Builds
    let child: Builds
    @State var title = "t"

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: stack([label(title), Tile(builds: child, tag: title).body]))
    }
}

private struct FlagOwner: ContentView {
    let builds: Builds
    let reader: Builds
    @State var flag = false

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: stack([FlagReader(builds: reader, flag: $flag).body]))
    }
}

private struct FlagReader: ContentView {
    let builds: Builds
    @Binding var flag: Bool

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: label("\(flag)"))
    }
}

/// A button whose taps are the proof that handlers survive being carried.
///
/// The handler captures the view's own `@State` box, exactly as an
/// application's does - a write through it is tracked, so the walk after a
/// tap has something to act on.
private struct TapCounter: ContentView {
    @State var count = 0

    var content: any View {
        Button("Count: \(count)").onClicked { count += 1 }
    }
}

/// Its body's ROOT depends on its own state - a Button in one state, a Label
/// in the other. No stored class here: in the test package a handler closure
/// capturing a plain class inside a `content` getter hops to MainActor
/// silently, so state stays in `@State` boxes the way an application holds it.
private struct Switcher: ContentView {
    @State var editing = false
    @State var taps = 0

    var content: any View {
        if editing {
            return Button("done").onClicked { taps += 1 }
        }

        return Label("view \(taps)")
    }
}

/// A builder `if` with no `else`, and a sibling AFTER it - the case `Node.key`
/// exists for: matched by position alone, the sibling would move whenever the
/// branch appears.
private struct Fields: ContentView {
    @State var editing = false

    var content: any View {
        VStack {
            if editing {
                Label("banner")
            }

            Label("sibling")
        }
    }
}

/// A `ForEach` whose length IS the state, each row named with `.id()`.
private struct RowList: ContentView {
    @State var n = 2

    var content: any View {
        VStack {
            ForEach(0..<n) { i in
                Label("row \(i)").id("r\(i)")
            }
        }
    }
}

/// A view holding another, each with state of its own - the walk has to find
/// a dirty view DEEP under clean ancestors, not only beside the root.
private struct Outer: ContentView {
    let builds: Builds
    let innerBuilds: Builds
    let innerCount: State<Int>
    @State var title = "t"

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: stack([label(title), Inner(builds: innerBuilds, count: innerCount).body]))
    }
}

private struct Inner: ContentView {
    let builds: Builds
    let count: State<Int>

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: label("inner \(count.get())"))
    }
}

/// A PAGE holding the choice its content shows - the shape a tabbed sample
/// page has. Its root node is built directly (a page's node is its properties,
/// its content and its slots), so the state is read inside a container BELOW
/// that root rather than on it.
private struct Tabbed: ContentPage {
    let builds: Builds
    @State var showing = 0

    var content: any View {
        builds.count += 1
        return Grid {
            Label("one").isVisible(showing == 0).gridRow(1).id("one")
            Label("two").isVisible(showing == 1).gridRow(1).id("two")
        }
    }
}

final class InvalidationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    /// What a test hands the walk: the changes the writes since the last
    /// render left with the renderer.
    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    // MARK: - The clean walk

    func testAChangedStateRebuildsOnlyTheViewThatReadIt() {
        let renders = Renders()
        let a = Builds(), b = Builds()
        let left = Tile(builds: a, tag: "L")
        let right = Tile(builds: b, tag: "R")

        renders.render(stack([left.body, right.body], id: "root"))
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(b.count, 1)

        right.n = 42

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(a.count, 1, "nothing the left tile reads has changed")
        XCTAssertEqual(b.count, 2, "the right tile read what moved")
        XCTAssertEqual(patch.child(.auto(2))?.props["text"], .string("R42"))
        XCTAssertNil(patch.child(.auto(1)), "the message says nothing about the left tile")
    }

    func testACleanWalkWithNothingDirtyBuildsNothing() {
        let renders = Renders()
        let a = Builds()
        let tile = Tile(builds: a, tag: "x")

        renders.render(stack([tile.body], id: "root"))

        let patch = renders.revisit(changed: [])

        XCTAssertEqual(a.count, 1)
        XCTAssertTrue(patch.isEmpty, "a walk that found nothing says nothing")
    }

    func testAParentRebuiltCarriesAChildBuiltWithTheSameInputs() {
        let renders = Renders()
        let parent = Builds(), child = Builds()
        let panel = Panel(builds: parent, child: child)

        renders.render(stack([panel.body], id: "root"))
        XCTAssertEqual(parent.count, 1)
        XCTAssertEqual(child.count, 1)

        panel.title = "T"

        renders.revisit(changed: changed)

        // A rebuilt parent writes a FRESH placeholder for its child, with
        // freshly computed inputs - and the child compares them against the
        // ones it stands on. The same inputs, nothing read that moved: the
        // child is carried.
        XCTAssertEqual(parent.count, 2)
        XCTAssertEqual(child.count, 1)
    }

    func testAParentRebuiltRebuildsAChildItHandsSomethingNew() {
        let renders = Renders()
        let parent = Builds(), child = Builds()
        let panel = Handing(builds: parent, child: child)

        renders.render(stack([panel.body], id: "root"))
        panel.title = "T"
        let patch = renders.revisit(changed: changed)

        // The child was built with the title, and the title moved.
        XCTAssertEqual(parent.count, 2)
        XCTAssertEqual(child.count, 2)
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(3))?.props["text"], .string("T0"))
    }

    func testAParentsRebuildSendsOnlyWhatChanged() {
        let renders = Renders()
        let parent = Builds(), child = Builds()
        let panel = Panel(builds: parent, child: child)

        renders.render(stack([panel.body], id: "root"))

        panel.title = "T"
        let patch = renders.revisit(changed: changed)

        // The child was CARRIED - built with the same inputs - so the message
        // carries the title's label and nothing else.
        XCTAssertEqual(child.count, 1)
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("T"))
        XCTAssertNil(
            patch.child(.auto(1))?.child(.auto(3))?.props["text"],
            "the child's text did not change, so the rebuild sent nothing for it")
    }

    func testABindingWriteDirtiesTheReaderNotTheOwner() {
        let renders = Renders()
        let owner = Builds(), reader = Builds()
        let view = FlagOwner(builds: owner, reader: reader)

        renders.render(stack([view.body], id: "root"))
        XCTAssertEqual(owner.count, 1)
        XCTAssertEqual(reader.count, 1)

        view.flag = true

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(owner.count, 1, "the owner lends the flag and never reads it")
        XCTAssertEqual(reader.count, 2, "the reader's build read it through the binding")
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("true"))
    }

    func testHandlersSurviveTheCleanWalk() {
        let renders = Renders()
        let view = TapCounter()

        let first = renders.render(stack([view.body], id: "root"))
        let id = first.child(.auto(1))?.events?["clicked"]
        XCTAssertNotNil(id)

        // Walks that carry the button over untouched.
        renders.revisit(changed: [])
        renders.revisit(changed: [])

        XCTAssertTrue(renders.fire(id!), "a carried element keeps its handlers registered")

        // The tap wrote tracked state, so the walk that follows knows exactly
        // which view to build again - the whole loop, closed.
        let patch = renders.revisit(changed: changed)
        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("Count: 1"))
    }

    // MARK: - Builder paths under the clean walk

    /// A page's own state, read inside the container its content is.
    ///
    /// The read happens when the DIFFER runs the container's content, which is
    /// after the body that wrote it has returned - and a page's root node is
    /// built directly, so the deferred content sits BELOW the node the
    /// unwrapping ends on. THE CONTAINER IS THE READER: its content is built
    /// again when the state moves, and the page's own body - which read
    /// nothing - is not.
    ///
    /// What it looks like when the read is recorded nowhere: the panels stand
    /// still while everything with state of its own beside them - a tab strip
    /// reading the same value through a binding - moves.
    func testAPagesStateReadByItsContentRebuildsTheContentAlone() {
        let renders = Renders()
        let builds = Builds()
        let page = Tabbed(builds: builds)

        let first = renders.render(page.body)
        XCTAssertEqual(builds.count, 1)
        let grid = first.children.first
        XCTAssertEqual(grid?.child("one")?.props["isVisible"], .bool(true))
        XCTAssertEqual(grid?.child("two")?.props["isVisible"], .bool(false))

        page.showing = 1
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(builds.count, 1, "the page's body read nothing; the Grid's content did")
        let moved = patch.children.first
        XCTAssertEqual(moved?.child("one")?.props["isVisible"], .bool(false))
        XCTAssertEqual(moved?.child("two")?.props["isVisible"], .bool(true))
    }

    func testABranchSwitchUnderTheCleanWalkReplacesAndForgetsItsHandler() {
        let renders = Renders()
        let view = Switcher()

        let first = renders.render(stack([view.body], id: "root"))
        XCTAssertEqual(first.child(.auto(1))?.props["text"], .string("view 0"))

        view.editing = true
        let toButton = renders.revisit(changed: changed)

        XCTAssertEqual(toButton.child(.auto(1))?.replace, true,
                       "a Label cannot become a Button by patching")
        let id = toButton.child(.auto(1))?.events?["clicked"]
        XCTAssertNotNil(id)

        // The tap writes `taps` - which THIS branch does not read, so the walk
        // that follows finds nothing to rebuild. That is the promise, not a
        // miss: nothing on screen shows the value.
        Renderer.shared.clearInvalidation()
        XCTAssertTrue(renders.fire(id!))
        let afterTap = renders.revisit(changed: changed)
        XCTAssertTrue(afterTap.isEmpty, "nothing shown depends on the count yet")

        // Switching back reads it - and shows the tap that landed meanwhile,
        // because the state survived both branch switches.
        Renderer.shared.clearInvalidation()
        view.editing = false
        let toLabel = renders.revisit(changed: changed)
        XCTAssertEqual(toLabel.child(.auto(1))?.props["text"], .string("view 1"))

        // The button is gone, and so is its handler - kept, it would be the
        // registry's leak.
        XCTAssertFalse(renders.fire(id!), "a handler of a branch that left is forgotten")
    }

    func testAnIfWithNoElseKeepsItsSiblingUnderTheCleanWalk() {
        let renders = Renders()
        let view = Fields()

        renders.render(stack([view.body], id: "root"))

        view.editing = true
        let patch = renders.revisit(changed: changed)

        // The sibling moved from 0 to 1 and nothing else about it changed: no
        // replace, no properties - it kept its element, riding the arranged
        // list as a stub, and with it whatever a control holds. The banner is
        // the one new child.
        let stackPatch = patch.child(.auto(1))
        let sibling = stackPatch?.child(.auto(2))
        XCTAssertEqual(stackPatch?.children.map(\.id), [.auto(3), .auto(2)],
                       "the banner above, the sibling below - the list is the order")
        XCTAssertEqual(sibling?.replace, false)
        XCTAssertEqual(sibling?.props.isEmpty, true)
        XCTAssertEqual(stackPatch?.child(.auto(3))?.props["text"], .string("banner"))

        Renderer.shared.clearInvalidation()
        view.editing = false
        let back = renders.revisit(changed: changed)

        XCTAssertEqual(back.child(.auto(1))?.arranged, true)
        XCTAssertEqual(back.child(.auto(1))?.children.map(\.id), [.auto(2)],
                       "the banner is simply no longer in the list")
    }

    func testAForGrownByItsStateSendsOnlyTheNewRow() {
        let renders = Renders()
        let view = RowList()

        renders.render(stack([view.body], id: "root"))

        view.n = 3
        let grown = renders.revisit(changed: changed)

        let stackPatch = grown.child(.auto(1))
        XCTAssertEqual(stackPatch?.child("r2")?.props["text"], .string("row 2"))
        XCTAssertEqual(stackPatch?.child("r0")?.isEmpty, true,
                       "an unchanged row rides the arranged list as a stub")
        XCTAssertEqual(stackPatch?.child("r1")?.isEmpty, true)
        XCTAssertEqual(stackPatch?.children.count, 3)

        Renderer.shared.clearInvalidation()
        view.n = 1
        let shrunk = renders.revisit(changed: changed)

        XCTAssertEqual(shrunk.child(.auto(1))?.children.map(\.id), [.manual("r0")],
                       "the rows that left are the ones the complete list no longer names")
    }

    func testADirtyViewIsFoundDeepUnderCleanAncestors() {
        let renders = Renders()
        let outer = Builds(), inner = Builds()
        let count = State(0)
        let view = Outer(builds: outer, innerBuilds: inner, innerCount: count)

        renders.render(stack([view.body], id: "root"))
        XCTAssertEqual(outer.count, 1)
        XCTAssertEqual(inner.count, 1)

        // The inner view's state changes; the outer never read it.
        count.wrappedValue = 7
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(outer.count, 1, "the outer view was not even walked into a build")
        XCTAssertEqual(inner.count, 2)
        XCTAssertEqual(
            patch.child(.auto(1))?.child(.auto(3))?.props["text"], .string("inner 7"))

        // The outer's own state rebuilds the outer alone: the inner was built
        // with the same inputs and read nothing that moved.
        Renderer.shared.clearInvalidation()
        view.title = "T"
        renders.revisit(changed: changed)

        XCTAssertEqual(outer.count, 2)
        XCTAssertEqual(inner.count, 2, "built with the same inputs, the inner view is carried")
    }

    func testTwoDirtyViewsInOneWalkBothRebuild() {
        let renders = Renders()
        let a = Builds(), b = Builds()
        let left = Tile(builds: a, tag: "L")
        let right = Tile(builds: b, tag: "R")

        renders.render(stack([left.body, right.body], id: "root"))

        left.n = 1
        right.n = 2
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(a.count, 2)
        XCTAssertEqual(b.count, 2)
        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("L1"))
        XCTAssertEqual(patch.child(.auto(2))?.props["text"], .string("R2"))
    }

    // MARK: - State under a memo

    /// A COMPOSED VIEW IS ITS OWN TOKEN, and what it read is the other half
    /// of it: a view carried for its inputs is still the reader of every
    /// state its body read, and a write to one builds it again - whether or
    /// not its parent is described.
    func testAStateReadUnderACarriedViewRebuildsIt() {
        let renders = Renders()
        let builds = Builds()
        let view = Tile(builds: builds, tag: "m")

        func tree() -> Node {
            stack([view.id("row").body], id: "root")
        }

        renders.render(tree())
        XCTAssertEqual(builds.count, 1)

        view.n = 1
        let patch = renders.render(tree(), changed: changed)
        XCTAssertEqual(builds.count, 2, "the view read what moved")
        XCTAssertEqual(patch.child("row")?.props["text"], .string("m1"))
    }

    /// A render that names nothing - an untracked cause - still carries a
    /// composed view whose inputs and reads both stand: what such a view
    /// shows comes from those two and from nothing else, and a state a body
    /// read names itself on every write, whatever asked for the render.
    func testAnUntrackedRenderStillCarriesAComposedView() {
        let renders = Renders()
        let builds = Builds()
        let view = Tile(builds: builds, tag: "m")

        func tree() -> Node {
            stack([view.id("row").body], id: "root")
        }

        renders.render(tree())
        let patch = renders.render(tree())
        XCTAssertEqual(builds.count, 1, "nothing it was built with moved, and it read nothing that did")
        XCTAssertNil(patch.child("row")?.props["text"], "and nothing was sent")
    }

    // MARK: - The message

    func testTheCleanWalkSendsExactlyWhatTheFullBuildWould() {
        let full = Renders(), clean = Renders()
        let a = Tile(builds: Builds(), tag: "x")
        let b = Tile(builds: Builds(), tag: "x")

        full.render(stack([label("above"), a.body], id: "root"))
        clean.render(stack([label("above"), b.body], id: "root"))

        a.n = 7
        b.n = 7

        let fromFull = full.render(stack([label("above"), a.body], id: "root"), changed: changed)
        let fromClean = clean.revisit(changed: changed)

        XCTAssertEqual(
            Wire.encode(fromFull, generation: 1, dictionary: WireDictionary()),
            Wire.encode(fromClean, generation: 1, dictionary: WireDictionary()),
            "the two paths must be indistinguishable on the wire")
    }

    // MARK: - The renderer's choice of path

    /// A write landing WHILE a render runs asks for the next one rather than
    /// being wiped by this one's bookkeeping.
    ///
    /// The renderer takes and clears its change set in one step BEFORE the
    /// build, so a write from a pool thread - a `Task.detached` with an
    /// answer, an `async let` child - that crosses mid-build stays on the
    /// books. A body writing as it builds stands in for that thread here:
    /// the write lands after the take, exactly where a crossing would.
    func testAWriteDuringTheRenderIsKeptForTheNextOne() {
        let page = WritingPage.shared
        page.writes = 1
        page.count.wrappedValue = 0

        Renderer.shared.setApplication(WritingApp())
        Renderer.shared.clearInvalidation()

        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertEqual(page.count.wrappedValue, 1, "the body wrote once")
        XCTAssertTrue(
            Renderer.shared.needsRender,
            "a write that landed after the take is still pending")
        XCTAssertEqual(
            Renderer.shared.pendingChanges, [ObjectIdentifier(page.count.lender)],
            "and names its state, so the next render is a clean walk")
    }

    /// A write to a state nobody reads asks for nothing - EXCEPT while a
    /// render runs, where it goes on the books as any write does. An element
    /// counts itself as a reader only as it is MADE, after its build has read,
    /// so a write landing in between could find no reader yet; rather than be
    /// dropped for good it asks, and the render that follows walks to nothing
    /// at worst. See `Renderer.rendering`.
    func testAWriteNobodyReadsDuringARenderIsKeptAllTheSame() {
        let aside = Aside.shared
        aside.writes = 1
        aside.unread.wrappedValue = 0

        Renderer.shared.setApplication(AsideApp())
        Renderer.shared.clearInvalidation()

        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertEqual(aside.unread.wrappedValue, 1, "the body wrote once, mid-render")
        XCTAssertTrue(Renderer.shared.needsRender, "and the write asked, readers or none")
        XCTAssertTrue(
            Renderer.shared.pendingChanges.contains(ObjectIdentifier(aside.unread.storage)),
            "naming the state as any write does")

        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        XCTAssertFalse(Renderer.shared.needsRender, "the render that followed walked to nothing")

        aside.unread.wrappedValue = 5
        XCTAssertFalse(
            Renderer.shared.needsRender,
            "and between renders the same write asks for nothing")
    }

    /// And what the window build STOPS reading stops counting: a page chosen
    /// by one state and then by another leaves the first read by nobody.
    func testWhatTheWindowBuildStopsReadingStopsCounting() {
        let chosen = Chosen.shared
        chosen.byFirst = true
        chosen.first.wrappedValue = "first"
        chosen.other.wrappedValue = "other"

        Renderer.shared.setApplication(ChosenApp())
        Renderer.shared.clearInvalidation()
        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertTrue(Renderer.shared.isRead(chosen.first.storage))
        XCTAssertFalse(Renderer.shared.isRead(chosen.other.storage))

        chosen.byFirst = false
        Renderer.shared.setNeedsRender()
        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertFalse(Renderer.shared.isRead(chosen.first.storage), "the window build no longer reads it")
        XCTAssertTrue(Renderer.shared.isRead(chosen.other.storage))

        chosen.first.wrappedValue = "second"
        XCTAssertFalse(Renderer.shared.needsRender, "so a write to it asks for nothing")
    }

    /// What the window build reads outside every composed view - which page
    /// it shows, the bound path, whether the flyout shows - is read too, and a
    /// write to it asks for the render that builds the window again.
    func testWhatTheWindowBuildReadsCountsAsRead() {
        let chosen = Chosen.shared
        chosen.byFirst = true
        chosen.first.wrappedValue = "first"

        Renderer.shared.setApplication(ChosenApp())
        Renderer.shared.clearInvalidation()

        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        XCTAssertTrue(
            Renderer.shared.isRead(chosen.first.storage),
            "the window build counted as a reader")

        chosen.first.wrappedValue = "second"
        XCTAssertTrue(Renderer.shared.needsRender, "so a write to it asks")
    }

    /// A view that writes state it reads on EVERY build is an author error,
    /// and the one thing a kept mid-render write would turn into a render
    /// loop. A streak of renders that each end dirty again is how it is told
    /// apart from a legitimate crossing, which dirties one render and not
    /// the next: reported once, and the change dropped, so the loop ends.
    func testAViewWritingItsOwnStateOnEveryBuildIsReportedNotLooped() {
        let page = WritingPage.shared
        page.writes = Int.max
        page.count.wrappedValue = 0

        _ = WireProbe.decode(Renderer.shared.takeCommandsWire())
        Renderer.shared.setApplication(WritingApp())
        Renderer.shared.clearInvalidation()

        var generation: Int32 = 0
        var reported: [WireAct] = []

        for _ in 0 ..< Renderer.selfDirtyLimit {
            let message = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: generation))
            generation = Int32(message.generation)
            reported += WireProbe.decode(Renderer.shared.takeCommandsWire())
        }

        XCTAssertFalse(Renderer.shared.needsRender, "the streak ended with the change dropped")
        XCTAssertEqual(reported.map { $0.name }, ["handlerFailed"], "and reported exactly once")
        XCTAssertTrue(
            reported.first?.arguments.first?.string?.contains("writes state while it is being built")
                == true,
            "naming the error: \(reported.first?.arguments.first?.string ?? "")")
    }

    func testAStateWriteNamesItsStorage() {
        let state = State(0)
        let reader = reading { _ = state.get() }
        state.wrappedValue = 1

        XCTAssertFalse(Renderer.shared.pendingChanges.isEmpty)
        XCTAssertFalse(
            Renderer.shared.hasUntrackedCause,
            "a write that named its state is not a reason to build everything")
        _ = reader
    }

    // MARK: - Who reads what

    /// An element counts as a reader of what it read for exactly as long as it
    /// stands in a tree - counted as it is made, given back as it dies - so a
    /// write to what it read asks for a render while it stands and for nothing
    /// once it has gone. Rendered AGAIN in between, the fresh element takes
    /// over the count from the one it replaces without a gap.
    func testAReaderThatLeavesTheTreeStopsCounting() {
        let renders = Renders()
        let state = State(0)

        renders.render(stack([Shows(state: state).body], id: "root"))
        XCTAssertTrue(Renderer.shared.isRead(state.storage), "the element counted itself")

        renders.render(stack([Shows(state: state).body], id: "root"))
        XCTAssertTrue(Renderer.shared.isRead(state.storage), "the fresh element took over the count")

        Renderer.shared.clearInvalidation()
        state.wrappedValue = 1
        XCTAssertTrue(Renderer.shared.needsRender, "read, so a write asks")

        renders.render(stack([label("gone")], id: "root"))
        XCTAssertFalse(
            Renderer.shared.isRead(state.storage),
            "the element died with the tree and gave the count back")

        Renderer.shared.clearInvalidation()
        state.wrappedValue = 2
        XCTAssertFalse(Renderer.shared.needsRender, "so a write asks for nothing again")
    }

    /// A reader that goes on standing but STOPS READING a state stops counting
    /// for it: the element is built again, the fresh node's `reads` no longer
    /// name the state, and the node it replaced gives its count back as it
    /// dies. `decision ? first : second` in one expression is the smallest
    /// shape of it - no view appears or disappears, only what one of them read.
    func testAReaderThatStopsReadingStopsCounting() {
        let renders = Renders()
        let first = State(1), second = State(2)
        let chooser = Chooses(first: first, second: second)

        renders.render(stack([chooser.body], id: "root"))
        XCTAssertTrue(Renderer.shared.isRead(first.storage))
        XCTAssertFalse(Renderer.shared.isRead(second.storage), "the arm not taken read nothing")

        chooser.decision = false
        renders.render(stack([chooser.body], id: "root"), changed: changed)

        XCTAssertFalse(Renderer.shared.isRead(first.storage), "no longer read, no longer counted")
        XCTAssertTrue(Renderer.shared.isRead(second.storage))

        Renderer.shared.clearInvalidation()
        first.wrappedValue = 10
        XCTAssertFalse(Renderer.shared.needsRender, "a write to the state nobody reads now asks for nothing")

        second.wrappedValue = 20
        XCTAssertTrue(Renderer.shared.needsRender, "and one to the state read now asks")
    }

    /// The same, where the read moves between the two arms of an `if` - the
    /// view under the arm not taken is not built, so it reads nothing, and the
    /// one that was there before dies with its count.
    func testTheArmOfAnIfNotTakenReadsNothing() {
        let renders = Renders()
        let a = State(1), b = State(2)

        func tree(_ flag: Bool) -> Node {
            VStack {
                if flag {
                    Shows(state: a)
                } else {
                    Shows(state: b)
                }
            }
            .body
        }

        renders.render(tree(true))
        XCTAssertTrue(Renderer.shared.isRead(a.storage))
        XCTAssertFalse(Renderer.shared.isRead(b.storage))

        renders.render(tree(false))
        XCTAssertFalse(Renderer.shared.isRead(a.storage), "the arm that was left died with its count")
        XCTAssertTrue(Renderer.shared.isRead(b.storage))

        renders.render(tree(true))
        XCTAssertTrue(Renderer.shared.isRead(a.storage), "and back again, exactly once")
        XCTAssertFalse(Renderer.shared.isRead(b.storage))
    }

    /// Rows that leave a `ForEach` take their reads with them: three rows over
    /// three states, then one - the two that went are read by nobody.
    func testRowsThatLeaveAForEachStopCounting() {
        let renders = Renders()
        let states = [State(1), State(2), State(3)]

        func tree(_ shown: [Int]) -> Node {
            VStack {
                ForEach(shown) { index in Shows(state: states[index]) }
            }
            .body
        }

        renders.render(tree([0, 1, 2]))
        XCTAssertEqual(states.map { Renderer.shared.isRead($0.storage) }, [true, true, true])

        renders.render(tree([1]))
        XCTAssertEqual(
            states.map { Renderer.shared.isRead($0.storage) }, [false, true, false],
            "the rows that left gave their counts back; the one that stayed kept its")

        renders.render(tree([]))
        XCTAssertEqual(states.map { Renderer.shared.isRead($0.storage) }, [false, false, false])
    }

    /// When the whole tree goes, nothing it read is read any more - the count
    /// comes back to nought, not to some number a dead node left behind.
    func testADroppedTreeLeavesNothingRead() {
        let a = State(1), b = State(2)

        do {
            let renders = Renders()
            renders.render(stack([Shows(state: a).id("a").body, Shows(state: b).id("b").body], id: "root"))
            renders.render(stack([Shows(state: a).id("a").body, Shows(state: b).id("b").body], id: "root"))
            XCTAssertTrue(Renderer.shared.isRead(a.storage))
        }

        XCTAssertFalse(Renderer.shared.isRead(a.storage), "the tree is gone, and so is every reader in it")
        XCTAssertFalse(Renderer.shared.isRead(b.storage))
    }

    /// Two elements reading one state are two readers, and the state is still
    /// read when one of them goes.
    func testTwoReadersCountTwice() {
        let renders = Renders()
        let state = State(0)

        renders.render(stack([
            Shows(state: state).id("a").body,
            Shows(state: state).id("b").body,
        ], id: "root"))
        renders.render(stack([Shows(state: state).id("a").body], id: "root"))

        XCTAssertTrue(Renderer.shared.isRead(state.storage), "one reader left is still a reader")

        renders.render(stack([label("gone")], id: "root"))

        XCTAssertFalse(Renderer.shared.isRead(state.storage))
    }

    func testAPlainSetNeedsRenderIsUntracked() {
        Renderer.shared.setNeedsRender()

        XCTAssertTrue(
            Renderer.shared.hasUntrackedCause,
            "not knowing what moved must never mean guessing that nothing did")
    }

    func testATickerNamesItselfAndItsReadersFollow() {
        let renders = Renders()
        let builds = Builds()
        let ticker = Ticker(every: .seconds(1))

        struct Clock: ContentView {
            let builds: Builds
            let ticker: Ticker

            var content: any View {
                builds.count += 1
                return ModifiedContent(node: label("\(ticker.ticks)"))
            }
        }

        renders.render(stack([Clock(builds: builds, ticker: ticker).body], id: "root"))
        XCTAssertEqual(builds.count, 1)

        ticker.limit = 5

        XCTAssertFalse(Renderer.shared.hasUntrackedCause, "a ticker names itself")

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(builds.count, 2, "the view that read the ticker was built again")
        XCTAssertTrue(patch.isEmpty, "the text did not change, so nothing was sent")
    }

    func testReadsAreReRecordedByEachBuild() {
        let renders = Renders()
        let builds = Builds()
        let toggle = State(false)
        let counter = State(0)

        struct Either: ContentView {
            let builds: Builds
            let toggle: State<Bool>
            let counter: State<Int>

            var content: any View {
                builds.count += 1
                return ModifiedContent(node: toggle.get() ? label("\(counter.get())") : label("off"))
            }
        }

        func tree() -> Node {
            stack([Either(builds: builds, toggle: toggle, counter: counter).body], id: "root")
        }

        renders.render(tree())

        // The branch that did not run did not read `counter`, so a change to
        // it is not this view's business - the render leaves it alone.
        counter.wrappedValue = 1
        renders.revisit(changed: changed)
        XCTAssertEqual(builds.count, 1)

        // Flipping the toggle IS, and the rebuild re-records the reads - so
        // from here on `counter` is a dependency.
        Renderer.shared.clearInvalidation()
        toggle.wrappedValue = true
        renders.revisit(changed: changed)
        XCTAssertEqual(builds.count, 2)

        Renderer.shared.clearInvalidation()
        counter.wrappedValue = 2
        let patch = renders.revisit(changed: changed)
        XCTAssertEqual(builds.count, 3)
        XCTAssertEqual(patch.child(.auto(1))?.props["text"], .string("2"))
    }
}


/// A page whose body WRITES the state it shows - `writes` times, then stops.
/// A class so the two tests can reach it; the state is a box of its own so a
/// rebuilt page finds the same one. `@unchecked` for the reason every test
/// fixture is: one test at a time touches it.
private final class WritingPage: @unchecked Sendable {
    static let shared = WritingPage()

    let count = State(0)
    var writes = 0
}

private struct WritingBody: ContentPage {
    var content: any View {
        let page = WritingPage.shared
        let shown = page.count.wrappedValue

        if page.writes > 0 {
            page.writes -= 1
            page.count.wrappedValue = shown + 1
        }

        return ModifiedContent(node: label("\(shown)"))
    }
}

private struct WritingWindow: Window {
    var page: any Page { WritingBody() }
}

private struct WritingApp: Application {
    var scene: any Scene { WritingWindow() }
}

/// A state NO body reads, written by a page's body as it builds - the shape a
/// pool thread's write has when it lands mid-render.
private final class Aside: @unchecked Sendable {
    static let shared = Aside()

    let unread = State(0)
    var writes = 0
}

private struct AsideBody: ContentPage {
    var content: any View {
        let aside = Aside.shared

        if aside.writes > 0 {
            aside.writes -= 1
            aside.unread.wrappedValue += 1
        }

        return ModifiedContent(node: label("aside"))
    }
}

private struct AsideWindow: Window {
    var page: any Page { AsideBody() }
}

private struct AsideApp: Application {
    var scene: any Scene { AsideWindow() }
}

/// A window whose PAGE is chosen from a state - a read the window build makes
/// outside every composed view.
private final class Chosen: @unchecked Sendable {
    static let shared = Chosen()

    let first = State("first")
    let other = State("other")
    var byFirst = true
}

/// The page it shows, handed what was chosen.
private struct ChosenPage: ContentPage {
    let text: String

    var content: any View { ModifiedContent(node: label(text)) }
}

private struct ChosenWindow: Window {
    var page: any Page {
        ChosenPage(
            text: Chosen.shared.byFirst
                ? Chosen.shared.first.wrappedValue
                : Chosen.shared.other.wrappedValue)
    }
}

private struct ChosenApp: Application {
    var scene: any Scene { ChosenWindow() }
}
