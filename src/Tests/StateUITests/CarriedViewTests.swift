// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A composed view is described again when what it was built with changed, or
// when a state it read changed - and CARRIED, subtree and all, otherwise. Its
// inputs are its stored properties, compared by what they are: a value by
// equality, a lent state by the storage it lends, an object by identity, and a
// closure never - whatever cannot be compared counts as changed.
//
// These count the builds, because that is the only way to tell.

import XCTest
@_spi(Host) @testable import StateUI

private final class Builds {
    var count = 0
}

/// A composed view over one value, counting how often its content runs.
private struct Caption: ContentView {
    let text: String
    let builds: Builds

    var content: any View {
        builds.count += 1
        return Label(text)
    }
}

/// The same, handed a closure - an input nothing can compare.
private struct Pressed: ContentView {
    let text: String
    let builds: Builds
    let tapped: () -> Void

    var content: any View {
        builds.count += 1
        return Button(text).onClicked { tapped() }
    }
}

/// A composed view that READS what it is lent.
private struct Shown: ContentView {
    @Binding var text: String
    let builds: Builds

    var content: any View {
        builds.count += 1
        return Label(text)
    }
}

/// A composed view that hands what it is lent straight on, reading nothing.
private struct Typed: ContentView {
    @Binding var text: String
    let builds: Builds

    var content: any View {
        builds.count += 1
        return Entry($text)
    }
}

final class CarriedViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    // MARK: - What it was built with

    func testAComposedViewBuiltWithTheSameInputsIsCarried() {
        let renders = Renders()
        let builds = Builds()

        func tree(_ n: Int) -> Node {
            VStack {
                Label("n \(n)")
                Caption(text: "fixed", builds: builds)
            }.body
        }

        renders.render(tree(1))
        XCTAssertEqual(builds.count, 1)

        let patch = renders.render(tree(2))
        XCTAssertEqual(
            builds.count, 1,
            "the stack was described again and the caption's inputs had not moved")
        XCTAssertEqual(patch.children.count, 1, "only the label travels")
    }

    func testAComposedViewBuiltWithANewValueIsDescribedAgain() {
        let renders = Renders()
        let builds = Builds()

        func tree(_ n: Int) -> Node {
            VStack {
                Label("n \(n)")
                Caption(text: "caption \(n)", builds: builds)
            }.body
        }

        renders.render(tree(1))
        let patch = renders.render(tree(2))
        XCTAssertEqual(builds.count, 2, "a value it was built with moved")
        XCTAssertEqual(texts(in: patch).last, .string("caption 2"))
    }

    func testAClosureHandedToAComposedViewCountsAsChanged() {
        let renders = Renders()
        let builds = Builds()

        func tree(_ n: Int) -> Node {
            VStack {
                Label("n \(n)")
                Pressed(text: "fixed", builds: builds) {}
            }.body
        }

        renders.render(tree(1))
        renders.render(tree(2))
        XCTAssertEqual(
            builds.count, 2,
            "a closure cannot be compared, so the view is built as if it had changed")
    }

    // MARK: - What it read

    func testAStateReadInACarriedViewRebuildsItWhenTheStateMoves() {
        let renders = Renders()
        let builds = Builds()
        let text = State("a")
        let other = State(0)

        func tree() -> Node {
            VStack {
                Label("other \(other.wrappedValue)")
                Shown(text: text.projectedValue, builds: builds)
            }.body
        }

        renders.render(tree())
        XCTAssertEqual(builds.count, 1)

        // The stack is the reader of `other` and is described again for it;
        // the view under it is lent the same storage, so it is carried.
        other.wrappedValue = 1
        renders.revisit(changed: changed)
        XCTAssertEqual(builds.count, 1, "the same storage is lent, so nothing here moved")

        // The view READ the text, so it is the reader of it - and the stack,
        // which reads no text, is left alone.
        Renderer.shared.clearInvalidation()
        text.wrappedValue = "b"
        let patch = renders.revisit(changed: changed)
        XCTAssertEqual(builds.count, 2, "the view read what moved")
        XCTAssertEqual(texts(in: patch).first, .string("b"))
    }

    func testAStateHandedOnByACarriedViewRendersNobodyWhenItMoves() {
        let renders = Renders()
        let builds = Builds()
        let text = State("a")
        let other = State(0)

        func tree() -> Node {
            VStack {
                Label("other \(other.wrappedValue)")
                Typed(text: text.projectedValue, builds: builds)
            }.body
        }

        renders.render(tree())
        other.wrappedValue = 1
        renders.revisit(changed: changed)
        XCTAssertEqual(builds.count, 1, "lent the same storage, the field is carried")

        Renderer.shared.clearInvalidation()
        text.wrappedValue = "b"
        XCTAssertFalse(
            Renderer.shared.needsRender,
            "a state handed on is read by nobody, so a write to it asks for nothing")
    }

    // MARK: - What was written on it

    func testAHandlerWrittenOnACarriedViewIsTheNewestOne() throws {
        let renders = Renders()
        let builds = Builds()
        var heard: [Int] = []

        func tree(_ n: Int) -> Node {
            VStack {
                Label("n \(n)")
                Caption(text: "fixed", builds: builds)
                    .onTapped { heard.append(n) }
            }.body
        }

        let first = renders.render(tree(1))
        let id = try XCTUnwrap(first.children.last?.events?["tapped"])

        renders.render(tree(2))
        XCTAssertEqual(builds.count, 1, "the caption is carried")

        XCTAssertTrue(renders.fire(id))
        XCTAssertEqual(
            heard, [2],
            "the handler the parent wrote LAST is the one that runs - a handler captures "
                + "what the parent's closure computed, and that closure ran again")
    }

    func testAChangedModifierOnACarriedViewReachesTheWire() {
        let renders = Renders()
        let builds = Builds()

        func tree(_ n: Int) -> Node {
            VStack {
                Caption(text: "fixed", builds: builds)
                    .opacity(Double(n) / 10)
            }.body
        }

        renders.render(tree(5))
        let patch = renders.render(tree(6))
        XCTAssertEqual(
            patch.children.first?.props["opacity"], .number(0.6),
            "what is written ON the view is the parent's to change, carried or not")
    }

    // MARK: - Identity and the message

    func testMovingCarriedViewsReportsOnlyTheirPositions() {
        let renders = Renders()
        let builds = Builds()

        func row(_ text: String) -> Node {
            Caption(text: text, builds: builds).id(text).body
        }

        renders.render(stack([row("a"), row("b")], id: "root"))
        XCTAssertEqual(builds.count, 2)

        let patch = renders.render(stack([row("b"), row("a")], id: "root"))
        XCTAssertEqual(builds.count, 2, "swapping two rows builds neither")
        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(
            patch.children.map(\.id), [.manual("b"), .manual("a")],
            "the list itself says they swapped")
    }

    func testAResyncDescribesWhatACarriedViewWouldOmit() {
        let renders = Renders()
        let builds = Builds()

        func tree() -> Node {
            stack([Caption(text: "a", builds: builds).id("a").body], id: "root")
        }

        renders.render(tree())
        let resync = renders.renderFromScratch(tree())
        XCTAssertEqual(builds.count, 2, "a complete message builds everything")
        XCTAssertEqual(resync.child("a")?.props["text"], .string("a"))
    }

    private func texts(in patch: HostPatch) -> [PropValue] {
        var found: [PropValue] = []

        func walk(_ patch: HostPatch) {
            if let text = patch.props[.text] { found.append(text) }
            patch.children.forEach(walk)
        }

        walk(patch)
        return found
    }
}
