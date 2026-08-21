// State owns, Binding borrows.

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
}
