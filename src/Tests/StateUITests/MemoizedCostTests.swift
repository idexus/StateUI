// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StateUI

/// What a memoized subtree costs while its token holds.
///
/// A memo's promise is that an unchanged token means the subtree is not built.
/// These hold the promise against what actually happens.
final class MemoizedCostTests: XCTestCase {
    /// How many times the memoized view's body has run.
    nonisolated(unsafe) static var inner = 0

    /// The view whose body must not run while the token holds.
    private struct Inner: Element {
        let shown: Int

        var body: Node {
            MemoizedCostTests.inner += 1
            return VStack { Label("shown \(shown)") }.body
        }
    }

    /// A page holding a memoized grid, rebuilt because something ELSE moved.
    private struct Page: Element {
        let chosen: Int

        var body: Node {
            VStack {
                Label("chosen \(chosen)")
                Grid { Inner(shown: chosen) }.memoized(by: 1)
            }.body
        }
    }

    /// A CONTAINER'S CONSTRUCTION BUILDS NOTHING. The closure is kept, and
    /// runs when the differ describes the grid - which is what lets a memo's
    /// token, written after this line, prevent it.
    func testAContainerBuildsNothingWhenItIsConstructed() {
        Self.inner = 0

        // Constructed, never rendered.
        _ = Grid { Inner(shown: 7) }

        XCTAssertEqual(Self.inner, 0, "construction keeps the closure unrun")
    }

    /// The saving itself: a token that holds means the content runs ONCE,
    /// however many times the page around it is rebuilt.
    func testAMemoizedSubtreeBuildsOnceWhileItsTokenHolds() {
        let renders = Renders()
        Self.inner = 0

        _ = renders.render(Page(chosen: 1).body)
        _ = renders.render(Page(chosen: 2).body)
        _ = renders.render(Page(chosen: 3).body)

        XCTAssertEqual(Self.inner, 1, "built once; the token held for the rest")
    }

    /// And the work is thrown away: the subtree is built, not sent, so the
    /// screen keeps the old text while the new one has just been computed.
    func testWhatIsBuiltUnderAHoldingTokenIsNotSent() {
        let renders = Renders()
        Self.inner = 0

        _ = renders.render(Page(chosen: 1).body)
        let patch = renders.render(Page(chosen: 2).body)

        XCTAssertEqual(
            patch.children.count, 1,
            "only the label outside the memo travels")
    }
}

/// The guarantees a lazily-described tree owes.
///
/// The memo tests above say what must STOP happening; these say what must go
/// on happening once it does. They are the whole safety net for making a
/// container describe its children when the differ asks rather than when the
/// author writes it down.
final class LazyDescriptionTests: XCTestCase {
    nonisolated(unsafe) static var built = 0

    /// A view that counts its own builds and shows a value.
    private struct Counted: Element {
        let shown: Int

        var body: Node {
            LazyDescriptionTests.built += 1
            return Label("shown \(shown)").body
        }
    }

    private struct Page: Element {
        let chosen: Int
        let token: Int

        var body: Node {
            VStack {
                Label("chosen \(chosen)")
                Grid { Counted(shown: chosen) }.memoized(by: token)
            }.body
        }
    }

    /// A TOKEN THAT MOVES STILL SHOWS THE NEW VALUE. The saving must never
    /// cost correctness: when the inputs change, the subtree is built and
    /// what it says reaches the wire.
    func testAMemoizedSubtreeUpdatesWhenItsTokenChanges() {
        let renders = Renders()
        Self.built = 0

        _ = renders.render(Page(chosen: 1, token: 1).body)
        let patch = renders.render(Page(chosen: 2, token: 2).body)

        XCTAssertEqual(Self.built, 2, "the token moved, so it was built again")

        // The grid's own child carries the new text.
        let text = patch.children
            .flatMap { $0.children }
            .compactMap { $0.props[.text] }

        XCTAssertEqual(
            text.first, .string("shown 2"),
            "what the rebuilt subtree says reaches the wire")
    }

    /// STATE INSIDE A LAZILY DESCRIBED CHILD STILL BELONGS TO IT. Whoever
    /// describes a child, the state it reads is adopted by its own path - not
    /// by whoever happened to run the closure.
    func testStateInsideAContainerSurvivesRedescription() {
        struct Holder: Element {
            @State private var count = 0
            let bump: Int

            var body: Node {
                Grid {
                    Label("held \(count) bumped \(bump)")
                }.body
            }
        }

        let renders = Renders()

        _ = renders.render(Holder(bump: 1).body)
        let patch = renders.render(Holder(bump: 2).body)

        let text = patch.children.compactMap { $0.props[.text] }

        XCTAssertEqual(
            text.first, .string("held 0 bumped 2"),
            "the state kept its value across a redescription")
    }

    /// AN ENVIRONMENT PROVIDED ABOVE REACHES A CHILD IN A CONTAINER. Before
    /// the description was lazy this did not answer wrongly, it ABORTED: the
    /// container ran its content in its own initializer, before the ancestor
    /// writing `.environment()` had been described, and an unanswered
    /// `@Environment` is a `preconditionFailure`.
    func testAnEnvironmentReachesALazilyDescribedChild() {
        final class Theme: @unchecked Sendable {
            let name: String
            init(_ name: String) { self.name = name }
        }

        // Written the way an application writes views - `content`, not a raw
        // `body` - because that is what gives a view its placeholder, and the
        // placeholder is where `@Environment` is resolved.
        struct Deep: ContentView {
            @Environment var theme: Theme

            var content: Element { Label(theme.name) }
        }

        struct Above: ContentView {
            let theme: Theme

            var content: Element {
                VStack {
                    Grid { Deep() }
                }
                .environment(theme)
            }
        }

        let renders = Renders()
        let patch = renders.render(Above(theme: Theme("dark")).body)

        XCTAssertEqual(
            texts(in: patch).first, .string("dark"),
            "the provider above was in scope where the child was described")
    }

    /// Every text prop anywhere in a patch, in walk order.
    private func texts(in patch: Patch) -> [PropValue] {
        var found: [PropValue] = []

        func walk(_ patch: Patch) {
            if let text = patch.props[.text] { found.append(text) }
            patch.children.forEach(walk)
        }

        walk(patch)
        return found
    }
    /// THE TOKEN GOVERNS THE CONTENT. A container's content closure runs
    /// while its token moves and at no other time - whatever the content
    /// reads while it runs. That is the whole of what the word promises: a
    /// reader who writes `.memoized(by: 1)` is saying this content is the
    /// same every time, and the library takes them at their word.
    ///
    /// Reading state that changes does NOT re-run it. A read is not one of
    /// the inputs the token names, and honouring it anyway would mean a memo
    /// saves nothing the moment anything under it touches state - which is
    /// most subtrees worth memoizing.
    func testTheTokenAloneDecidesWhetherContentRuns() {
        let renders = Renders()
        let builds = Builds()
        let view = Reader(builds: builds)

        func tree() -> Node {
            Node(type: "VerticalStackLayout", children: [
                VStack { view }.memoized(by: 1).id("row").body,
            ])
        }

        renders.render(tree())
        XCTAssertEqual(builds.count, 1)

        view.n = 7

        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(
            builds.count, 1,
            "the token held, so the content did not run again")
    }

    /// And the token MOVING runs it, with everything the content now reads.
    func testAMovedTokenRunsTheContentAgain() {
        let renders = Renders()
        let builds = Builds()
        let view = Reader(builds: builds)

        func tree(_ token: Int) -> Node {
            Node(type: "VerticalStackLayout", children: [
                VStack { view }.memoized(by: token).id("row").body,
            ])
        }

        renders.render(tree(1))
        XCTAssertEqual(builds.count, 1)

        view.n = 7

        let patch = renders.render(tree(2), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 2, "the token moved, so the content ran")
        XCTAssertEqual(
            patch.child("row")?.children.first?.props["text"], .string("n7"),
            "and what it now says reaches the wire")
    }

    /// And the other half: content that reads NOTHING is skipped whatever
    /// else on the page moves - which is the saving the token is for.
    func testAMemoizedContainerThatReadsNothingIsSkipped() {
        let renders = Renders()
        let builds = Builds()
        let mover = Reader(builds: Builds())

        func tree() -> Node {
            Node(type: "VerticalStackLayout", children: [
                VStack { Blank(builds: builds) }.memoized(by: 1).id("row").body,
                mover.body,
            ])
        }

        renders.render(tree())
        XCTAssertEqual(builds.count, 1)

        mover.n = 7

        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(
            builds.count, 1,
            "nothing in there read what moved, so nothing was built")
    }
}

/// How many times something was built.
private final class Builds {
    var count = 0
}

/// A view that reads its own state and counts its builds.
private struct Reader: ContentView {
    let builds: Builds
    @State var n = 0

    var content: Element {
        builds.count += 1
        return Label("n\(n)")
    }
}

/// A view that reads nothing at all.
private struct Blank: ContentView {
    let builds: Builds

    var content: Element {
        builds.count += 1
        return Label("blank")
    }
}
