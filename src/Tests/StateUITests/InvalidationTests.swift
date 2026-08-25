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

/// A composed view that reads its own `@State` and counts its builds.
private struct Tile: ContentView {
    let builds: Builds
    let tag: String
    @State var n = 0

    var content: Element {
        builds.count += 1
        return label("\(tag)\(n)")
    }
}

/// A parent whose body builds a Tile afresh each time it runs.
private struct Panel: ContentView {
    let builds: Builds
    let child: Builds
    @State var title = "t"

    var content: Element {
        builds.count += 1
        return stack([label(title), Tile(builds: child, tag: "c").body])
    }
}

/// Owns a flag it never reads - only lends. The reader is what depends on it.
private struct FlagOwner: ContentView {
    let builds: Builds
    let reader: Builds
    @State var flag = false

    var content: Element {
        builds.count += 1
        return stack([FlagReader(builds: reader, flag: $flag).body])
    }
}

private struct FlagReader: ContentView {
    let builds: Builds
    @Binding var flag: Bool

    var content: Element {
        builds.count += 1
        return label("\(flag)")
    }
}

/// A button whose taps are the proof that handlers survive being carried.
///
/// The handler captures the view's own `@State` box, exactly as an
/// application's does - a write through it is tracked, so the walk after a
/// tap has something to act on.
private struct TapCounter: ContentView {
    @State var count = 0

    var content: Element {
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

    var content: Element {
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

    var content: Element {
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

    var content: Element {
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

    var content: Element {
        builds.count += 1
        return stack([label(title), Inner(builds: innerBuilds, count: innerCount).body])
    }
}

private struct Inner: ContentView {
    let builds: Builds
    let count: State<Int>

    var content: Element {
        builds.count += 1
        return label("inner \(count.get())")
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

    func testAParentRebuiltRebuildsWhatItWrites() {
        let renders = Renders()
        let parent = Builds(), child = Builds()
        let panel = Panel(builds: parent, child: child)

        renders.render(stack([panel.body], id: "root"))
        XCTAssertEqual(parent.count, 1)
        XCTAssertEqual(child.count, 1)

        panel.title = "T"

        renders.revisit(changed: changed)

        // The cascade rule: a rebuilt parent writes a FRESH placeholder for
        // its child, with freshly computed inputs - so the child builds too,
        // and no input comparison is ever needed.
        XCTAssertEqual(parent.count, 2)
        XCTAssertEqual(child.count, 2)
    }

    func testAParentsRebuildSendsOnlyWhatChanged() {
        let renders = Renders()
        let parent = Builds(), child = Builds()
        let panel = Panel(builds: parent, child: child)

        renders.render(stack([panel.body], id: "root"))

        panel.title = "T"
        let patch = renders.revisit(changed: changed)

        // The child was BUILT again - the cascade - but building is not
        // sending: its text came out the same, so the message carries the
        // title's label and nothing else.
        XCTAssertEqual(child.count, 2)
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

        // The outer's own state cascades down, and the inner keeps reading the
        // value it kept.
        Renderer.shared.clearInvalidation()
        view.title = "T"
        renders.revisit(changed: changed)

        XCTAssertEqual(outer.count, 2)
        XCTAssertEqual(inner.count, 3, "a rebuilt parent rebuilds what it writes")
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

    func testAStateUnderAnUnchangedMemoStillUpdates() {
        let renders = Renders()
        let builds = Builds()
        let view = Tile(builds: builds, tag: "m")

        func tree() -> Node {
            stack([view.memoized(by: "fixed").id("row").body], id: "root")
        }

        renders.render(tree())
        XCTAssertEqual(builds.count, 1)

        view.n = 1

        let patch = renders.render(tree(), changed: changed)

        // The token is unchanged, so the INPUTS are - but state a body reads
        // is not an input, and the skip now walks the carried subtree for it.
        XCTAssertEqual(builds.count, 2, "the unchanged token no longer hides the state change")
        XCTAssertEqual(patch.child("row")?.props["text"], .string("m1"))
    }

    func testAnUntrackedRenderKeepsTheMemoSkip() {
        let renders = Renders()
        let builds = Builds()
        let view = Tile(builds: builds, tag: "m")

        func tree() -> Node {
            stack([view.memoized(by: "fixed").id("row").body], id: "root")
        }

        renders.render(tree())
        view.n = 1

        // A render with an EMPTY changed set is what an untracked cause
        // produces: nothing named, nothing to walk for. The skip behaves as it
        // always did - which is the memo's documented promise, everything the
        // view shows coming from its inputs.
        let patch = renders.render(tree())

        XCTAssertEqual(builds.count, 1)
        XCTAssertNil(patch.child("row")?.props["text"])
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

        let fromFull = full.render(stack([label("above"), a.body], id: "root"))
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
        state.wrappedValue = 1

        XCTAssertFalse(Renderer.shared.pendingChanges.isEmpty)
        XCTAssertFalse(
            Renderer.shared.hasUntrackedCause,
            "a write that named its state is not a reason to build everything")
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

            var content: Element {
                builds.count += 1
                return label("\(ticker.ticks)")
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

            var content: Element {
                builds.count += 1
                return toggle.get() ? label("\(counter.get())") : label("off")
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
    var content: Element {
        let page = WritingPage.shared
        let shown = page.count.wrappedValue

        if page.writes > 0 {
            page.writes -= 1
            page.count.wrappedValue = shown + 1
        }

        return label("\(shown)")
    }
}

private struct WritingWindow: Window {
    var content: Page { WritingBody() }
}

private struct WritingApp: Application {
    func createWindow() -> Window { WritingWindow() }
}
