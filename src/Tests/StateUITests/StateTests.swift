// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State owns, Binding borrows.

import Foundation
import XCTest
@testable import StateUI

private struct Owner {
    @State var counter = 0
    @State var name = ""

    func borrower() -> Borrower { Borrower(counter: $counter, name: $name) }
}

/// A plain value with more than one field in it, to lend one field of.
private struct Profile {
    var name = "unnamed"
    var age = 30
}

private struct Settings {
    @State var profile = Profile()

    /// What `Entry($profile.name)` would be given.
    var name: Binding<String> { $profile.name }
}

private struct Borrower {
    @Binding var counter: Int
    @Binding var name: String

    /// Not mutating, because a view cannot be: the box is what changes.
    func bump() {
        counter += 1
        name = "typed"
    }
}

/// A view that OWNS its state - rebuilt on every render, like any view, which
/// is exactly what the differ has to see through.
private struct Counter: ContentView {
    @State var count = 0

    var content: Element {
        Button("Count: \(count)").onClicked { count += 1 }
    }
}

/// A different kind of view at the same place, which must NOT inherit
/// Counter's state.
private struct Timer: ContentView {
    @State var count = 100

    var content: Element {
        Button("Tick: \(count)").onClicked { count += 1 }
    }
}

/// A view that stores an unbuilt element IN FRONT OF its own state - the shape
/// a lazy list's layout has, and the one a pairing that went by position got
/// wrong the moment the slot filled.
///
/// The element is stored BARE, without a modifier: a modifier wraps it in a
/// `Node`, which the state walk stops at, and a slot holding a node has no
/// state to shift.
private struct Shelf: ContentView {
    /// What sits above the count, when anything does.
    let extra: Element?

    @State var count = 0

    var content: Element {
        VStack {
            if let extra {
                extra
            }

            Button("Shelf: \(count)").onClicked { count += 1 }
        }
    }
}

/// A page whose state is read BESIDE its content - the title and the view on
/// the navigation bar hang off the page, not under it - which is why a page is
/// deferred too.
private struct QueryPage: ContentPage {
    @State var query = ""

    var title: String? { "Results: \(query)" }

    var navigationPageTitleView: Element? {
        SearchBar($query).placeholder("Type here")
    }

    var content: Element {
        Label(query)
    }
}

/// A page whose title answers nil once it has answered a value - the shape
/// EVERY optional property of a page and a window has, `title.map { … }`, and
/// the one whose clearing must not take the state under it down.
private struct TitledPage: ContentPage {
    let titled: Bool

    var title: String? { titled ? "Named" : nil }

    var content: Element {
        Counter()
    }
}

/// How many times a closure was built - a class, so a closure the view keeps
/// can count into it.
private final class Builds {
    var count = 0
}

/// A view whose content is one read the test chooses.
private struct Shown: ContentView {
    let read: () -> Void

    init(_ read: @escaping () -> Void) {
        self.read = read
    }

    var content: Element {
        read()
        return Label("shown")
    }
}

final class StateTests: XCTestCase {
    func testAdoptingABoxSharesItsStorageBothWays() {
        let old = State(1)
        let fresh = State(0)

        fresh.adopt(from: old)

        old.wrappedValue = 5
        XCTAssertEqual(fresh.get(), 5, "a write through last render's box reaches this render")

        fresh.wrappedValue = 7
        XCTAssertEqual(old.get(), 7, "and a handler holding the old box reads the new value")
    }

    func testABindingCanBeBuiltFromAGetterAndASetter() {
        var held = "start"

        let binding = Binding(get: { held }, set: { held = $0 })

        XCTAssertEqual(binding.wrappedValue, "start")

        binding.wrappedValue = "typed"

        XCTAssertEqual(held, "typed", """
            The escape hatch: a binding to something this library does not own. \
            Whether the write asks for a render is then the setter's business - \
            this one owns nothing, so nothing was asked for.
            """)
    }

    func testABindingReachesOnePropertyOfAValue() {
        let owner = Settings()

        let name = owner.name

        XCTAssertEqual(name.wrappedValue, "unnamed")

        name.wrappedValue = "typed"

        XCTAssertEqual(owner.profile.name, "typed", """
            `$profile.name` reads the whole value, writes the property and puts \
            the whole back through the binding - which is what makes it work for \
            a struct as much as for a class.
            """)
        XCTAssertEqual(owner.profile.age, 30, "and leaves the rest of it alone")
    }

    func testStateOnAViewSurvivesTheRebuild() {
        let renders = Renders()

        let first = renders.render(Counter().body)
        renders.fire(first.events?["clicked"] ?? -1)

        // A fresh value, as every render makes one - same identity, same type.
        let second = renders.render(Counter().body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.props["text"], .string("Count: 1"),
                       "the rebuilt view kept the tapped count")

        renders.fire(first.events?["clicked"] ?? -1)
        let third = renders.render(Counter().body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(third.props["text"], .string("Count: 2"),
                       "and keeps on keeping it")
    }

    func testADifferentViewTypeAtTheSamePlaceStartsOver() {
        let renders = Renders()

        let first = renders.render(Counter().body)
        renders.fire(first.events?["clicked"] ?? -1)

        let second = renders.render(Timer().body)

        XCTAssertEqual(second.props["text"], .string("Tick: 100"),
                       "another kind of view starts with its own initial value")
    }

    func testADifferentIdentityStartsOverToo() {
        let renders = Renders()

        let first = renders.render(stack([Counter().id("a").body]))
        renders.fire(first.child("a")?.events?["clicked"] ?? -1)

        let second = renders.render(stack([Counter().id("b").body]))

        XCTAssertEqual(second.child("b")?.props["text"], .string("Count: 0"),
                       "an element the author renamed is a new element, state included")
    }

    func testAViewInsideAViewKeepsItsOwnState() {
        struct Wrapper: ContentView {
            var content: Element {
                VStack { Counter() }
            }
        }

        let renders = Renders()

        let first = renders.render(Wrapper().body)
        renders.fire(first.children.first?.events?["clicked"] ?? -1)

        let second = renders.render(Wrapper().body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.children.first?.props["text"], .string("Count: 1"))
    }

    func testAStoredViewThatArrivesLeavesTheStateBehindItAlone() {
        let renders = Renders()

        // Nothing on the shelf yet, so its own count is the only state the
        // walk finds.
        let first = renders.render(Shelf(extra: nil).body)
        renders.fire(first.children[0].events?["clicked"] ?? -1)

        // The slot fills, and what it fills with owns state of its own - found
        // FIRST, the property being declared first. Paired by position, the
        // newcomer would take the shelf's count and the shelf would be handed
        // nothing.
        let second = renders.render(Shelf(extra: Counter()).body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.children.count, 2, "the slot's view and the shelf's own button")
        XCTAssertEqual(second.children[1].props["text"], .string("Shelf: 1"),
                       "the state declared after the slot is still the shelf's own")
    }

    func testAStoredViewThatArrivesStartsAtItsOwnInitialValue() {
        let renders = Renders()

        let first = renders.render(Shelf(extra: nil).body)
        renders.fire(first.children[0].events?["clicked"] ?? -1)

        let second = renders.render(Shelf(extra: Counter()).body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.children[0].props["text"], .string("Count: 0"),
                       "a path nobody answered last render is state that starts over")

        // And the two are two: moving the newcomer moves nothing else.
        renders.fire(second.children[0].events?["clicked"] ?? -1)

        let third = renders.render(Shelf(extra: Counter()).body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(third.children.count, 1,
                       "the shelf's own count did not move, so nothing is said about it")
        XCTAssertEqual(third.children[0].props["text"], .string("Count: 1"))
    }

    /// One BRANCH holding another view type each render - a type-erased
    /// factory inside a stored builder list - is another path: the branch key
    /// alone would hand Timer the count Counter left behind.
    func testABranchHoldingAnotherViewTypeStartsOver() {
        struct Holder: ContentView {
            let parts: [Element]

            init(@ViewBuilder _ parts: () -> [Element]) {
                self.parts = parts()
            }

            var content: Element {
                VStack { parts }
            }
        }

        func make(ticking: Bool) -> Holder {
            let branch = true

            return Holder {
                if branch {
                    ticking ? Timer() as any Element : Counter()
                }
            }
        }

        let renders = Renders()

        let first = renders.render(make(ticking: false).body)
        renders.fire(first.children[0].events?["clicked"] ?? -1)

        let second = renders.render(make(ticking: true).body)

        XCTAssertEqual(second.children[0].props["text"], .string("Tick: 100"),
                       "a branch that holds another view type is another path")
    }

    func testAPageThatLosesItsTitleKeepsTheStateUnderIt() {
        let renders = Renders()

        let first = renders.render(TitledPage(titled: true).body)
        let clicked = first.children[0].events?["clicked"] ?? -1

        renders.fire(clicked)

        let second = renders.render(
            TitledPage(titled: false).body, changed: Renderer.shared.pendingChanges)

        XCTAssertFalse(second.replace, "the page is not built again")
        XCTAssertEqual(second.cleared, ["title"], "the property that went away is named instead")

        // Nothing under the page was rebuilt, so the handler the counter
        // registered on the FIRST render is still the one it answers to, and
        // the tap it was given still stands.
        renders.fire(clicked)

        let third = renders.render(
            TitledPage(titled: false).body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(third.children[0].props["text"], .string("Count: 2"))
    }

    func testStateReadBesideTheContentSeesTheSurvivingValue() {
        let renders = Renders()

        let first = renders.render(QueryPage().body)
        let slot = first.children.first { $0.type == "NavigationPageTitleView" }
        let search = slot?.children.first
        let number = search?.driven?[.text]?.number

        XCTAssertNotNil(number, "the search bar is handed the query, and the host carries it")

        // What the reader types is the HOST's write onto that state.
        typed(number ?? -1, "alpha")

        // The page's own properties and its slots are built from the same
        // boxes the content is, AFTER adoption - so the title and the label
        // both see the typed query; the search bar shows it from the state.
        let second = renders.render(QueryPage().body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.props["title"], .string("Results: alpha"))
        XCTAssertEqual(second.children.first { $0.type == "Label" }?.props["text"],
                       .string("alpha"))
    }

    func testABorrowedValueStaysItsOwnersAcrossRebuilds() {
        struct Borrowing: ContentView {
            @Binding var counter: Int

            var content: Element {
                Button("Count: \(counter)").onClicked { counter += 1 }
            }
        }

        // The owner - what an application is.
        let counter = State(10)
        let renders = Renders()

        let first = renders.render(Borrowing(counter: counter.projectedValue).body)
        renders.fire(first.events?["clicked"] ?? -1)

        XCTAssertEqual(counter.get(), 11, "the write went to the owner, not a copy")

        let second = renders.render(
            Borrowing(counter: counter.projectedValue).body, changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(second.props["text"], .string("Count: 11"))
    }

    func testAWriteThroughABindingReachesTheOwner() {
        let owner = Owner()
        owner.borrower().bump()

        XCTAssertEqual(owner.counter, 1)
        XCTAssertEqual(owner.name, "typed")
    }

    func testAClosureThatOutlivesTheViewStillWrites() {
        let owner = Owner()
        let borrower = owner.borrower()

        // What a button handler is: a closure kept until someone taps.
        let later: () -> Void = { borrower.counter += 10 }
        later()

        XCTAssertEqual(owner.counter, 10)
    }

    func testAWriteAsksForARender() {
        let state = State(0)
        let reader = reading { _ = state.get() }
        Renderer.shared.clearInvalidation()

        state.wrappedValue = 1

        XCTAssertTrue(Renderer.shared.needsRender, "a write marks the tree dirty")
        _ = reader
    }

    /// A write NOBODY reads asks for nothing: no live element read the state,
    /// so nothing on screen could change for it - and it is not even named.
    /// What it costs is the storage's lock and one look at the readers; no
    /// dirty tree, no wake, no walk. See `Renderer.stateChanged`.
    func testAWriteNobodyReadsAsksForNothing() {
        Renderer.shared.clearInvalidation()
        let state = State(0)

        state.wrappedValue = 1

        XCTAssertFalse(Renderer.shared.needsRender, "nobody reads it, so nothing could change")
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty, "and it is not even named")
    }

    func testUpdateReadsAndWritesInOneStep() {
        let state = State(5)
        state.update { $0 * 2 }

        XCTAssertEqual(state.get(), 10)
    }
}


extension StateTests {
    /// State is written from ANY thread, whole: a hundred detached tasks each
    /// counting a hundred times through `update` land every count, because
    /// the read, the change and the write happen under one hold of the lock.
    /// The wrapper's `+= 1` is a read and then a write and could not promise
    /// this from two tasks at once - which is what `update` is for.
    func testUpdateFromManyTasksAtOnceCountsEveryOne() async {
        let counter = State(0)
        let reader = reading { _ = counter.get() }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    await Task.detached {
                        for _ in 0 ..< 100 {
                            counter.update { $0 + 1 }
                        }
                    }.value
                }
            }
        }

        XCTAssertEqual(counter.get(), 10_000)
        XCTAssertTrue(Renderer.shared.needsRender, "and every one of them asked for a render")
        _ = reader
    }

    /// Reads and writes from many threads at once are whole values, never a
    /// mix of two: a value wider than a word is written under the lock, so a
    /// reader sees one write or the other and nothing in between.
    func testAWideValueIsNeverReadTorn() async {
        let wide = State((a: 0, b: 0, c: 0, d: 0))

        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await Task.detached {
                    for n in 1 ... 2_000 { wide.wrappedValue = (n, n, n, n) }
                }.value
                return true
            }

            for _ in 0 ..< 4 {
                group.addTask {
                    await Task.detached {
                        for _ in 0 ..< 2_000 {
                            let read = wide.get()
                            if read.a != read.b || read.b != read.c || read.c != read.d {
                                return false
                            }
                        }
                        return true
                    }.value
                }
            }

            for await whole in group {
                XCTAssertTrue(whole, "a read saw two writes mixed")
            }
        }
    }

    // MARK: - Reading a value the host is moving

    /// Drains the executor - the host's job, here done by hand - until `done`
    /// answers true or `seconds` have passed. Answers whether it happened.
    ///
    /// The one test here that involves real time needs it: a reading booked
    /// for the end of a window is a sleeping Task, and nothing turns the
    /// executor in a test.
    @discardableResult
    private func drain(until done: () -> Bool, within seconds: Double = 3) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)

        while Date() < deadline {
            stateUIRunJobs()

            if done() { return true }

            Thread.sleep(forTimeInterval: 0.002)
        }

        return done()
    }

    /// Two frames inside one window take ONE reading: the first at once, the
    /// second finding the window closed and booking one for its end, and a
    /// third covered by the booking already standing.
    ///
    /// The moment is STATED rather than slept for, so the arithmetic is read
    /// exactly and the test costs nothing.
    func testTwoFramesInsideOneWindowTakeOneReading() {
        let sampling = Sampling(window: 100, take: {})
        let now = ContinuousClock.now

        XCTAssertEqual(sampling.due(at: now), .now, "the first frame is read at once")

        XCTAssertEqual(
            sampling.due(at: now + .milliseconds(10)),
            .waitUntil(now + .milliseconds(100)),
            "the second books a reading for the end of the window")

        XCTAssertEqual(
            sampling.due(at: now + .milliseconds(20)), .waiting,
            "and the third is covered by the booking already standing")
    }

    /// A frame after the window has passed is read at once again, and starts
    /// the next window from itself rather than from the one before.
    func testAFrameAfterTheWindowIsReadAtOnce() {
        let sampling = Sampling(window: 100, take: {})
        let now = ContinuousClock.now

        XCTAssertEqual(sampling.due(at: now), .now)

        XCTAssertEqual(
            sampling.due(at: now + .milliseconds(101)), .now,
            "the window had passed")

        XCTAssertEqual(
            sampling.due(at: now + .milliseconds(150)),
            .waitUntil(now + .milliseconds(201)),
            "and the next window runs from the reading that was taken")
    }

    /// A READ OF THE JOURNEY IS A BUILD PER FRAME, AND A READ OF THE STATE IS
    /// NOT. Two readers over one value the host is walking: a body that prints
    /// `fade` reads the destination, which no frame of the walk moves; a body
    /// that prints `$fade.journey.value` asked to see every frame, and is
    /// built on every one of them. Two reader sets, one keyed by the state and
    /// one by the image the host walks it on - see
    /// `State.Storage.askJourneyReaders()`.
    func testAJourneyReadIsABuildPerFrameAndADestinationReadIsNot() {
        let fade = State(1.0)
        let destination = Builds()
        let journey = Builds()
        let renders = Renders()

        renders.render(stack([
            Shown { destination.count += 1; _ = fade.get() }.body,
            Shown { journey.count += 1; _ = fade.projectedValue.journey.value }.body,
        ], id: "root"))
        _ = Renderer.shared.renderWire(baseline: 0)
        XCTAssertEqual(destination.count, 1)
        XCTAssertEqual(journey.count, 1)

        // Three frames of a walk: the value moving, the destination standing.
        for value in [0.9, 0.8, 0.7] {
            moved(fade.number, to: [value, 1, 0, 0, 0, 0, 0, 0], mask: 0b1)
            _ = renders.revisit(changed: Renderer.shared.pendingChanges)
            Renderer.shared.clearInvalidation()
        }

        XCTAssertEqual(destination.count, 1, """
            A body that printed the DESTINATION was built for a frame of the \
            walk, which moves nothing it printed.
            """)
        XCTAssertEqual(journey.count, 4, """
            A body that printed the JOURNEY was not built for a frame of the \
            walk - the number it shows is stale, and nothing says so.
            """)
        XCTAssertEqual(fade.projectedValue.journey.value, 0.7)
        XCTAssertEqual(fade.wrappedValue, 1, "and the state itself stood at its destination throughout")
    }

    /// A READING IS OF WHERE THE VALUE HAS GOT TO, never of where it is going.
    ///
    /// This is the whole design in one assertion. A state is at its value the
    /// moment it is written, so a walked one stands at its DESTINATION from
    /// the first frame - a sample that read the state would copy that
    /// destination over and over and nothing would ever appear to move. What
    /// it reads is the value's own lane, which the host writes as it walks.
    func testASampleReadsWhereTheValueHasGotToAndNotItsDestination() {
        let fade = State(1.0)
        let shown = State(1.0)
        let renders = Renders()

        renders.render(stack([
            Shown { _ = shown.get() }
                .samples(fade.projectedValue, into: shown.projectedValue, .every(0))
                .body,
        ], id: "root"))

        // The host says: going to 0, and got as far as 0.75 so far.
        moved(fade.number, to: [0.75, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertEqual(shown.get(), 0.75, """
            The reading took the DESTINATION rather than where the value has \
            got to - which is the same number for the whole of a walk, so \
            nothing would ever appear to move.
            """)
    }

    /// A reading that finds nothing new writes nothing - which is what makes a
    /// sample stop when the value lands, without anything having to notice
    /// that it did.
    func testAReadingThatFindsNothingNewAsksForNothing() {
        let fade = State(1.0)
        let shown = State(1.0)
        let renders = Renders()

        renders.render(stack([
            Shown { _ = shown.get() }
                .samples(fade.projectedValue, into: shown.projectedValue, .every(0))
                .body,
        ], id: "root"))
        _ = Renderer.shared.renderWire(baseline: 0)

        moved(fade.number, to: [0.5, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)
        XCTAssertTrue(Renderer.shared.needsRender, "the value moved, so the reading did")
        _ = Renderer.shared.renderWire(baseline: 0)

        // The same value again: the host says nothing new.
        moved(fade.number, to: [0.5, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertFalse(
            Renderer.shared.needsRender,
            "a reading of a value that has not moved wrote it again")
    }

    /// The last frame inside a window is BOOKED rather than dropped, so a
    /// sample ends where the value did rather than one frame short of it.
    func testTheLastFrameInAWindowIsStillRead() {
        let fade = State(1.0)
        let shown = State(1.0)
        let renders = Renders()

        renders.render(stack([
            Shown { _ = shown.get() }
                .samples(fade.projectedValue, into: shown.projectedValue, .every(30))
                .body,
        ], id: "root"))

        moved(fade.number, to: [0.5, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)
        XCTAssertEqual(shown.get(), 0.5, "the first frame is read at once")

        moved(fade.number, to: [0.25, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertTrue(
            drain(until: { shown.get() == 0.25 }),
            "the frame inside the window was dropped, so the sample ends short")
    }

    /// A READING ENDS WITH THE VIEW THAT ASKED FOR IT, and holds nothing alive
    /// after it - which is what keeps a page's states from outliving the page.
    ///
    /// The reading writes the target and reads the source, so it holds both;
    /// the SOURCE's image is where it is kept. Held there strongly, the three
    /// make a ring - source, image, reading, and the closure back to the
    /// source - and no state of that page is ever freed. Every visit leaves
    /// another set behind, and the board walks all of them on every frame it
    /// runs.
    func testAReadingEndsWithTheViewThatAskedForIt() {
        weak var source: State<Double>.Storage?

        do {
            let fade = State(1.0)
            let shown = State(1.0)
            let renders = Renders()

            renders.render(stack([
                Shown { _ = shown.get() }
                    .samples(fade.projectedValue, into: shown.projectedValue, .every(100))
                    .body,
            ], id: "root"))

            source = fade.storage
            XCTAssertNotNil(source, "the state is alive while the view is")
        }

        XCTAssertNil(source, """
            The reading outlived the view that asked for it and holds the value \
            it reads, so the page's states are never freed.
            """)
    }

    /// A READING'S WINDOW SURVIVES THE RENDER ITS OWN WRITE ASKS FOR, and that
    /// is the whole of what keeps a cadence a cadence.
    ///
    /// The loop is the one this feature is made of: a reading writes an
    /// ORDINARY state, that write asks for a render, and the render walks the
    /// very view that asked for the reading. Installed afresh there, the
    /// window starts over - so the next frame is read as a first frame, it
    /// asks for the render that resets the window again, and a reading at any
    /// rate is taken on every frame the host sends.
    func testAReadingSurvivesTheRenderItsOwnWriteAsks() {
        let fade = State(1.0)
        let shown = State(1.0)
        let renders = Renders()

        func tree() -> Node {
            stack([
                Shown { _ = shown.get() }
                    .samples(fade.projectedValue, into: shown.projectedValue, .every(100_000))
                    .body,
            ], id: "root")
        }

        renders.render(tree())

        moved(fade.number, to: [0.75, 1, 0, 0, 0, 0, 0, 0], mask: 0b1)
        XCTAssertEqual(shown.get(), 0.75, "the first frame is read at once")

        // What that write asked for: the body reads `shown`, so the view that
        // carries the reading is described again.
        renders.render(tree())

        moved(fade.number, to: [0.5, 1, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertEqual(shown.get(), 0.75, """
            The window was thrown away by the render the reading's own write \
            asked for, so the next frame counted as a first frame.
            """)
    }

    /// TWO READINGS OF ONE VALUE ARE TWO READINGS, each with its own window -
    /// which is what a cadence kept on the state itself could never be, and
    /// the reason this is a modifier rather than a rider on the declaration.
    func testTwoViewsMayReadOneValueAtTwoRates() {
        let fade = State(1.0)
        let quick = State(1.0)
        let slow = State(1.0)
        let renders = Renders()

        renders.render(stack([
            Shown { _ = quick.get() }
                .samples(fade.projectedValue, into: quick.projectedValue, .every(0))
                .body,
            Shown { _ = slow.get() }
                .samples(fade.projectedValue, into: slow.projectedValue, .every(100_000))
                .body,
        ], id: "root"))

        moved(fade.number, to: [0.5, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)
        moved(fade.number, to: [0.25, 0, 0, 0, 0, 0, 0, 0], mask: 0b1)

        XCTAssertEqual(quick.get(), 0.25, "the reading with no window took both frames")
        XCTAssertEqual(slow.get(), 0.5, "the one with a long window took the first alone")
    }

    /// A WRITE MADE ON THIS SIDE ASKS AT ONCE, whatever anybody is sampling:
    /// there is no cadence on a state's own writes at all. An author who
    /// writes a value means it now.
    func testAWriteOnThisSideAsksAtOnce() {
        let shown = State(1.0)
        let reader = reading { _ = shown.get() }

        _ = Renderer.shared.renderWire(baseline: 0)
        XCTAssertFalse(Renderer.shared.needsRender)

        shown.wrappedValue = 0.5
        XCTAssertTrue(Renderer.shared.needsRender)
        _ = Renderer.shared.renderWire(baseline: 0)

        shown.wrappedValue = 0.25
        XCTAssertTrue(Renderer.shared.needsRender, "and the next one, at once as well")
        _ = reader
    }
}
