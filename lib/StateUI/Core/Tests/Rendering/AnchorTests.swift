// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A composed view's anchor: what is written on the view that outlives the branch its body shows - a watch, its
// lifetime, what it presents - stands on an element of no view of its own, which holds the view the body builds.

import XCTest
@_spi(Host) @testable import StateUI

/// A group of one branch or another, presenting a sheet while `shows` says so.
private struct Branching: View {
    let wide: Bool
    let shows: Binding<Bool>

    var body: some View {
        Group {
            if wide {
                HStack { Text("Wide") }
            } else {
                VStack { Text("Narrow") }
            }
        }
        .sheet(isPresented: shows) {
            Text("Sheet")
        }
    }
}

/// A group of one branch or another, saying when it comes and goes.
private struct Living: View {
    let wide: Bool
    let log: Binding<[String]>

    var body: some View {
        let log = self.log
        return Group {
            if wide { HStack { Text("Wide") } } else { VStack { Text("Narrow") } }
        }
        .onCreated { log.wrappedValue.append("created") }
        .onDestroying { log.wrappedValue.append("destroying") }
    }
}

/// A group of one titled branch or another, watching a value.
private struct TitledBranches: View {
    let wide: Binding<Bool>

    var body: some View {
        Group {
            if wide.wrappedValue { Text("Wide").title("Wide") } else { Text("Narrow").title("Narrow") }
        }
        .onChanged(wide.wrappedValue) {}
    }
}

/// A page presenting a sheet from an `if/else` its builder makes, no view of its own around it.
private struct Heading: View {
    let wide: Bool
    let shows: Binding<Bool>

    var body: some View {
        VStack {
            title
                .sheet(isPresented: shows) { Text("Sheet") }
                .opacity(0.5)
        }
    }

    @ViewBuilder private var title: some View {
        if wide { HStack { Text("Wide") } } else { VStack { Text("Narrow") } }
    }
}

/// A window's stack or, once `split`, its split view, presenting a sheet from the group holding them.
private struct StackPresenting: View {
    let shows: Binding<Bool>
    let split: Binding<Bool>
    @State private var path: [Int] = []

    var body: some View {
        Group {
            if split.wrappedValue {
                SplitView { Text("Sections") } detail: { Text("Detail") }.showsSidebar(State(wrappedValue: true).projectedValue)
            } else {
                NavigationStack($path) { Text("Home") } destination: { _ in Text("Next") }
            }
        }
        .sheet(isPresented: shows) { Text("Sheet") }
    }
}

/// A group of one word or another.
@MainActor private func branches(_ wide: Bool) -> Group<Either<Text, Text>> {
    Group {
        if wide { Text("Wide") } else { Text("Narrow") }
    }
}

@MainActor
final class AnchorTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// What outlives the branch a composed view shows stands on its anchor: the view its body builds is the
    /// anchor's child, the sheet beside it.
    func testWhatIsWrittenOnAComposedViewStandsOnItsAnchor() throws {
        let built = VStack { Branching(wide: false, shows: State(wrappedValue: false).projectedValue) }.node.built
        let anchor = try XCTUnwrap(built.children.first)

        XCTAssertEqual(anchor.type, .anchor)
        XCTAssertEqual(anchor.children.map(\.type), [.vStack, .sheet])
    }

    /// Written on a composed view, what is about its look stands on the view its body builds, and no anchor is
    /// made where nothing outliving a branch is written.
    func testAViewWithNothingToOutliveItsBranchesStandsAsWhatItsBodyBuilds() throws {
        let built = VStack {
            Group { Text("Plain") }.opacity(0.5).id("plain")
        }.node.built
        let shown = try XCTUnwrap(built.children.first)

        XCTAssertEqual(shown.type, .text)
        XCTAssertNotNil(shown.props[.opacity])
    }

    /// A view whose root never changes takes no anchor: what is written on it stands on that root, which stands as
    /// long as the view does.
    func testAViewWhoseRootNeverChangesTakesNoAnchor() throws {
        let built = VStack {
            Group { Text("Plain") }.onChanged(1) {}.sheet(isPresented: State(wrappedValue: false).projectedValue) {
                Text("Sheet")
            }
        }.node.built
        let shown = try XCTUnwrap(built.children.first)

        XCTAssertEqual(shown.type, .text)
        XCTAssertEqual(shown.watches.count, 1)
        XCTAssertEqual(shown.children.map(\.type), [.sheet])
    }

    /// Written on a view with an anchor, its look stands on the view its body builds, its identity on the anchor.
    func testTheLookStandsOnTheViewShownAndTheIdentityOnTheAnchor() throws {
        let built = VStack {
            branches(false).opacity(0.5).onChanged(1) {}.id("anchored")
        }.node.built
        let anchor = try XCTUnwrap(built.children.first)

        XCTAssertEqual(anchor.type, .anchor)
        XCTAssertEqual(anchor.identity, ElementIdentity("anchored"))
        XCTAssertNil(anchor.props[.opacity])
        XCTAssertNotNil(anchor.children.first?.props[.opacity])
    }

    /// The branch flipping replaces the view the anchor holds, and the anchor stands.
    func testABranchFlippingReplacesTheViewShownAndTheAnchorStands() throws {
        let renders = Renders()
        let shows = State(wrappedValue: false)
        let first = renders.render(VStack { Branching(wide: false, shows: shows.projectedValue) }.node)
        let flipped = renders.render(VStack { Branching(wide: true, shows: shows.projectedValue) }.node)

        let (before, after) = (try XCTUnwrap(first.children.first), try XCTUnwrap(flipped.children.first))
        XCTAssertEqual(after.type, .anchor)
        XCTAssertEqual(after.id, before.id)
        XCTAssertFalse(after.replace, "the anchor stands")
        XCTAssertEqual(after.children.first?.type, .hStack)
        XCTAssertEqual(after.children.first?.id, before.children.first?.id, "in the group's place")
        XCTAssertEqual(after.children.first?.replace, true, "the view shown made anew")
    }

    /// A sheet written on a group shows on as the group's branch flips: nothing presenting it left.
    func testASheetShowsOnAsTheBranchOfItsViewFlips() throws {
        let renders = Renders()
        let shows = State(wrappedValue: true)
        let first = renders.settled(VStack { Branching(wide: false, shows: shows.projectedValue) }.node)
        let sheet = try XCTUnwrap(first.subtree.first { $0.type == .sheet })

        let flipped = renders.settled(VStack { Branching(wide: true, shows: shows.projectedValue) }.node)

        XCTAssertTrue(shows.wrappedValue, "nothing closed it")
        XCTAssertNil(flipped.subtree.first { $0.type == .sheet && $0.replace }, "the sheet stands")
        XCTAssertEqual(flipped.subtree.first { $0.type == .anchor }?.id, first.subtree.first { $0.type == .anchor }?.id)
        XCTAssertNotNil(sheet.children.first, "it showed its page")
    }

    /// An `if/else` a builder makes keeps what is written on it the same way: its sheet shows on as it flips, and
    /// what is about its look, written after, stands on the branch it shows.
    func testAnIfElseKeepsItsSheetAsItFlips() throws {
        let renders = Renders()
        let shows = State(wrappedValue: true)
        let first = renders.settled(Heading(wide: false, shows: shows.projectedValue).node)
        let anchor = try XCTUnwrap(first.subtree.first { $0.type == .anchor })
        XCTAssertEqual(anchor.children.map(\.type), [.vStack, .sheet])
        XCTAssertNil(anchor.props[.opacity])
        XCTAssertEqual(anchor.children.first?.props[.opacity], .number(0.5))

        let flipped = renders.settled(Heading(wide: true, shows: shows.projectedValue).node)
        XCTAssertTrue(shows.wrappedValue, "nothing closed it")
        XCTAssertEqual(flipped.subtree.first { $0.type == .anchor }?.id, anchor.id)
        XCTAssertEqual(flipped.subtree.first { $0.type == .anchor }?.children.first?.type, .hStack)
    }

    /// The identity written on a composed view before what made its anchor is the anchor's.
    func testTheIdentityWrittenBeforeTheAnchorIsTheAnchors() throws {
        let built = VStack {
            branches(false).id("held").onChanged(1) {}
        }.node.built
        let anchor = try XCTUnwrap(built.children.first)

        XCTAssertEqual(anchor.type, .anchor)
        XCTAssertEqual(anchor.identity, ElementIdentity("held"))
        XCTAssertNil(anchor.children.first?.identity)
    }

    /// `.onCreated` and `.onDestroying` written on a composed view are the view's: its branch flipping runs
    /// neither, the view leaving runs the second.
    func testALifetimeWrittenOnAComposedViewIsTheViewsNotItsBranches() {
        let log = State(wrappedValue: [String]())
        let renders = Renders()
        let tree = { (wide: Bool, stands: Bool) in
            VStack { if stands { Living(wide: wide, log: log.projectedValue) } }.node
        }

        renders.render(tree(false, true))
        renders.render(tree(true, true), changed: Renderer.shared.pendingChanges)
        renders.render(tree(false, true), changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(log.wrappedValue, ["created"], "a branch flipping is no view coming or going")

        renders.render(tree(false, false), changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(log.wrappedValue, ["created", "destroying"])
    }

    /// An anchor standing where a page stands - a window's view - holds the arrangement its view builds: the
    /// arrangement stands there too, and so does the next as the anchor's view builds it again.
    func testAnArrangementAnAnchorHoldsStandsWhereThePageStands() throws {
        let (shows, split) = (State(wrappedValue: true), State(wrappedValue: false))
        let renders = Renders()
        let first = renders.settled(Node.window(
            StackPresenting(shows: shows.projectedValue, split: split.projectedValue), session: WindowSession()))
        let anchor = try XCTUnwrap(first.children.first)
        XCTAssertEqual(anchor.type, .anchor)
        XCTAssertEqual(anchor.children.map(\.type), [.navigationStack, .sheet])

        split.wrappedValue = true
        let flipped = renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(flipped.subtree.first { $0.type == .anchor }?.children.first?.type, .splitView)
    }

    /// What the view a page shows says of the page reaches it through the anchor: each branch's title.
    func testAPageHearsTheViewItsAnchorShows() throws {
        let renders = Renders()
        let wide = State(wrappedValue: false)
        let narrow = renders.settled(Node.window(TitledBranches(wide: wide.projectedValue), session: WindowSession()))
        wide.wrappedValue = true
        let widened = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(narrow.subtree.first { $0.type == .page }?.props[.title], .string("Narrow"))
        XCTAssertEqual(widened.subtree.first { $0.type == .page }?.props[.title], .string("Wide"))
    }
}
