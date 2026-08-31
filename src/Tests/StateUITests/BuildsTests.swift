// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a view answers when it is asked why it is being described. The reading
// is the author's instrument for "this scrolls badly": it names the state a
// rebuild came from, and says `with its parent` where the view is only along
// for the ride - which is what points at the view that actually reads too
// much.
//
// The mechanism is in Core/Builds.swift; the facts it reads are the differ's
// own - the reads recorded against an element, the changes a render carries,
// and the count kept on the element.

import XCTest
@testable import StateUI

/// Keeps what a view said about itself, so a test can read it back. A class,
/// so the walk that collects state boxes leaves it alone.
private final class Said {
    var last = ""
    var count = 0
}

/// A view that reads its own state and says why it is being described.
private struct Watched: ContentView {
    let said: Said
    @State var count = 0

    var content: Element {
        said.last = debugInfo()
        said.count += 1
        return label("count \(count)")
    }
}

/// A parent that reads a state of its own and holds a child that reads none.
private struct Holder: ContentView {
    let mine: Said
    let theirs: Said
    @State var title = "t"

    var content: Element {
        mine.last = debugInfo()
        return stack([label(title), Passenger(said: theirs).body])
    }
}

/// A view with no state at all - rebuilt only because its parent was.
private struct Passenger: ContentView {
    let said: Said

    var content: Element {
        said.last = debugInfo()
        return label("along")
    }
}

final class BuildsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    // MARK: - What it says

    /// The first description of a view has no state behind it, and says so.
    func testTheFirstBuildSaysItIsTheFirst() {
        let said = Said()
        let view = Watched(said: said)

        Renders().render(stack([view.body], id: "root"))

        XCTAssertEqual(said.last, "Watched: 1 build, first time")
    }

    /// A view rebuilt because its own state moved names that state, by the
    /// property the author declared it as.
    func testAViewNamesTheStateItWasBuiltFor() {
        let said = Said()
        let view = Watched(said: said)
        let renders = Renders()

        renders.render(stack([view.body], id: "root"))

        view.$count.wrappedValue = 1
        renders.revisit(changed: changed)

        XCTAssertEqual(said.last, "Watched: 2 builds, for count")
    }

    /// A view along for the ride says so rather than naming a state it never
    /// read - which is what tells the view that CAUSED a rebuild from the
    /// views under it.
    func testAViewUnderARebuiltOneSaysItCameWithItsParent() {
        let mine = Said(), theirs = Said()
        let holder = Holder(mine: mine, theirs: theirs)
        let renders = Renders()

        renders.render(stack([holder.body], id: "root"))

        holder.$title.wrappedValue = "moved"
        renders.revisit(changed: changed)

        XCTAssertEqual(mine.last, "Holder: 2 builds, for title")
        XCTAssertEqual(theirs.last, "Passenger: 2 builds, with its parent")
    }

    /// The count is the element's, carried across every render that leaves it
    /// alone - so it answers "how many times has this been rebuilt".
    func testTheBuildsAreCounted() {
        let said = Said()
        let view = Watched(said: said)
        let renders = Renders()

        renders.render(stack([view.body], id: "root"))

        for _ in 0..<3 {
            view.$count.wrappedValue += 1
            renders.revisit(changed: changed)
        }

        XCTAssertEqual(said.count, 4)
        XCTAssertEqual(said.last, "Watched: 4 builds, for count")
    }

    /// A whole-tree render is not about one state, and says that instead of
    /// naming whatever happened to be written.
    func testAWholeTreeRenderSaysSo() {
        let said = Said()
        let view = Watched(said: said)
        let renders = Renders()

        renders.render(stack([view.body], id: "root"))
        renders.renderFromScratch(stack([view.body], id: "root"))

        XCTAssertEqual(said.last, "Watched: 2 builds, the whole tree")
    }

    /// Outside every body there is nothing being described, and the reading
    /// says so rather than answering about whatever was described last.
    func testOutsideABodyThereIsNothingToSay() {
        let said = Said()

        Renders().render(stack([Watched(said: said).body], id: "root"))

        XCTAssertEqual(Label("x").debugInfo(), "nothing is being described here")
    }
}
