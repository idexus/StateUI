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
        let second = renders.render(Counter().body)

        XCTAssertEqual(second.props["text"], .string("Count: 1"),
                       "the rebuilt view kept the tapped count")

        renders.fire(first.events?["clicked"] ?? -1)
        let third = renders.render(Counter().body)

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

        let second = renders.render(Wrapper().body)

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
        let second = renders.render(Shelf(extra: Counter()).body)

        XCTAssertEqual(second.children.count, 2, "the slot's view and the shelf's own button")
        XCTAssertEqual(second.children[1].props["text"], .string("Shelf: 1"),
                       "the state declared after the slot is still the shelf's own")
    }

    func testAStoredViewThatArrivesStartsAtItsOwnInitialValue() {
        let renders = Renders()

        let first = renders.render(Shelf(extra: nil).body)
        renders.fire(first.children[0].events?["clicked"] ?? -1)

        let second = renders.render(Shelf(extra: Counter()).body)

        XCTAssertEqual(second.children[0].props["text"], .string("Count: 0"),
                       "a path nobody answered last render is state that starts over")

        // And the two are two: moving the newcomer moves nothing else.
        renders.fire(second.children[0].events?["clicked"] ?? -1)

        let third = renders.render(Shelf(extra: Counter()).body)

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

        let second = renders.render(TitledPage(titled: false).body)

        XCTAssertFalse(second.replace, "the page is not built again")
        XCTAssertEqual(second.cleared, ["title"], "the property that went away is named instead")

        // Nothing under the page was rebuilt, so the handler the counter
        // registered on the FIRST render is still the one it answers to, and
        // the tap it was given still stands.
        renders.fire(clicked)

        let third = renders.render(TitledPage(titled: false).body)

        XCTAssertEqual(third.children[0].props["text"], .string("Count: 2"))
    }

    func testStateReadBesideTheContentSeesTheSurvivingValue() {
        let renders = Renders()

        let first = renders.render(QueryPage().body)
        let slot = first.children.first { $0.type == "NavigationPageTitleView" }
        let search = slot?.children.first

        renders.fire(search?.events?["textChanged"] ?? -1, with: [.string("alpha")])

        // The page's own properties and its slots are built from the same
        // boxes the content is, AFTER adoption - so the title and the search
        // box both see the typed query.
        let second = renders.render(QueryPage().body)

        XCTAssertEqual(second.props["title"], .string("Results: alpha"))
        XCTAssertEqual(
            second.children
                .first { $0.type == "NavigationPageTitleView" }?
                .children.first?.props["text"],
            .string("alpha"))
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

        let second = renders.render(Borrowing(counter: counter.projectedValue).body)
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
        _ = Renderer.shared.needsRender      // whatever it was

        state.wrappedValue = 1

        XCTAssertTrue(Renderer.shared.needsRender, "a write marks the tree dirty")
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

    // MARK: - State the tree hears about on a cadence

    /// Drains the executor - the host's job, here done by hand - until `done`
    /// answers true or `seconds` have passed. Answers whether it happened.
    ///
    /// The one test here that involves real time needs it: a cadence's trailing
    /// render is a sleeping Task, and nothing turns the executor in a test.
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

    /// Two writes inside one window ask for ONE render: the first asks at
    /// once, the second finds the window closed and arms a wait, and a third
    /// is covered by the wait already standing.
    ///
    /// The moment is STATED rather than slept for, so the arithmetic is read
    /// exactly and the test costs nothing.
    func testTwoWritesInsideOneWindowAskOnce() {
        let state = State(0)
        let now = ContinuousClock.now

        XCTAssertEqual(
            state.storage.asks(atMostEvery: 100, at: now), .now,
            "the first write asks at once")

        XCTAssertEqual(
            state.storage.asks(atMostEvery: 100, at: now + .milliseconds(10)),
            .waitUntil(now + .milliseconds(100)),
            "the second write waits for the window to end")

        XCTAssertEqual(
            state.storage.asks(atMostEvery: 100, at: now + .milliseconds(20)), .waiting,
            "and the third is covered by the wait already standing")
    }

    /// A write after the window has passed asks at once again, and starts the
    /// next window from itself rather than from the one before - so a state
    /// written once a second on a 100ms cadence renders on every write.
    func testAWriteAfterTheWindowAsksAtOnce() {
        let state = State(0)
        let now = ContinuousClock.now

        XCTAssertEqual(state.storage.asks(atMostEvery: 100, at: now), .now)

        XCTAssertEqual(
            state.storage.asks(atMostEvery: 100, at: now + .milliseconds(101)), .now,
            "the window had passed")

        XCTAssertEqual(
            state.storage.asks(atMostEvery: 100, at: now + .milliseconds(150)),
            .waitUntil(now + .milliseconds(201)),
            "and the next window runs from the write that asked, not from the first")
    }

    /// The window is kept on the STORAGE, so a view described again between
    /// two writes does not start it over - the box is remade every render and
    /// adopts this one.
    func testTheWindowSurvivesTheViewBeingDescribedAgain() {
        let first = State(0)
        let now = ContinuousClock.now

        XCTAssertEqual(first.storage.asks(atMostEvery: 100, at: now), .now)

        let second = State(0)
        second.adopt(from: first)

        XCTAssertEqual(
            second.storage.asks(atMostEvery: 100, at: now + .milliseconds(10)),
            .waitUntil(now + .milliseconds(100)),
            "the rebuilt box started the window over")
    }

    /// A cadence is not a delay the reader waits out: the value is written
    /// where it is read AT ONCE, and only the ask for a render is held.
    func testTheValueItselfIsNeverHeldBack() {
        let state = State(wrappedValue: 0, every: 10_000)

        state.wrappedValue = 1
        state.wrappedValue = 2

        XCTAssertEqual(state.get(), 2, "the second write was held back")
    }

    /// And the second write inside the window asks for nothing, where an
    /// ordinary state asks on every write.
    func testASecondWriteInsideTheWindowAsksForNoRender() {
        let state = State(wrappedValue: 0, every: 10_000)

        state.wrappedValue = 1

        // A render is what clears the flag, so this is where "needs render"
        // means the write below and nothing before it.
        _ = Renderer.shared.renderWire(baseline: 0)
        XCTAssertFalse(Renderer.shared.needsRender)

        state.wrappedValue = 2

        XCTAssertFalse(
            Renderer.shared.needsRender,
            "a write inside the window asked for a render of its own")
    }

    /// The last write inside a window still gets its render when the window
    /// ends - without it, a value that stopped moving would leave the screen
    /// showing whatever the previous window ended on.
    func testTheLastWriteInAWindowStillGetsItsRender() {
        let state = State(wrappedValue: 0, every: 30)

        state.wrappedValue = 1

        _ = Renderer.shared.renderWire(baseline: 0)
        XCTAssertFalse(Renderer.shared.needsRender)

        state.wrappedValue = 2

        XCTAssertTrue(
            drain(until: { Renderer.shared.needsRender }),
            "the write inside the window never got its render")
    }

    /// Nought or less is every write, which is what a plain `@State` already is -
    /// so a cadence worked out from a number an author computed cannot turn
    /// into a state that never renders.
    func testACadenceOfNoughtIsEveryWrite() {
        let state = State(wrappedValue: 0, every: 0)

        _ = Renderer.shared.renderWire(baseline: 0)

        state.wrappedValue = 1
        XCTAssertTrue(Renderer.shared.needsRender)

        _ = Renderer.shared.renderWire(baseline: 0)

        state.wrappedValue = 2
        XCTAssertTrue(Renderer.shared.needsRender, "the second write asked for nothing")
    }

    /// A state on a cadence is still a state the tree DESCRIBES: the write
    /// NAMES it as what changed, so the render that follows rebuilds the views
    /// that read it. That is the whole difference from `@DrivenState`, which names
    /// nothing.
    func testAStateOnACadenceStillNamesItselfAsWhatChanged() {
        let state = State(wrappedValue: 0, every: 100)

        _ = Renderer.shared.renderWire(baseline: 0)

        state.wrappedValue = 1

        XCTAssertTrue(
            Renderer.shared.pendingChanges.contains(ObjectIdentifier(state.storage)),
            "the render would not know which views to rebuild")
    }
}
