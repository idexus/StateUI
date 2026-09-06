// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHO THE READER IS. A read at build makes the closure it happens in a reader
// of the state - the body, or the content of the container the read sits in -
// and a write to the state builds exactly that closure again: the container
// alone where the read is in a container, and nothing around it. Handing a
// state on as `$x` makes no reader at all (CarriedStateTests).

import XCTest
@testable import StateUI

/// Keeps what a closure saw and how often it ran.
private final class Said {
    var last = ""
    var count = 0
}

/// A body whose read sits in a NESTED container: the HStack's content reads
/// `x`, the VStack's content and the body itself do not.
private struct Outer: ContentView {
    let body: Said
    let inner: Said

    @State var x = 0

    var content: Element {
        body.count += 1

        return VStack {
            Label("still")

            HStack {
                Label("x \(x)")
                Label(seen())
            }
        }
    }

    /// Runs where the HStack's content runs, and keeps what it said.
    func seen() -> String {
        inner.count += 1
        inner.last = debugInfo()
        return inner.last
    }
}

/// A body that reads in the BODY ITSELF, outside every container.
private struct Direct: ContentView {
    let body: Said

    @State var x = 0

    var content: Element {
        body.count += 1

        let title = "x \(x)"

        return VStack {
            Label(title)
        }
    }
}

final class ReaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    /// A read inside a container's braces makes THAT container the reader:
    /// its content is built again when the state moves, and the body around
    /// it - which read nothing - is not.
    func testTheReaderIsTheClosureThatRead() {
        let body = Said(), inner = Said()
        let view = Outer(body: body, inner: inner)
        let renders = Renders()

        renders.render(stack([view.body], id: "root"))
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(inner.count, 1)

        view.$x.wrappedValue = 1
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(body.count, 1, "the body read nothing, so it was not built again")
        XCTAssertEqual(inner.count, 2, "the HStack's content read `x`, so it was")

        // What crossed: the way down to the HStack, and its changed label -
        // the sibling that stood outside the braces is not on the message.
        let outer = patch.children.first
        XCTAssertEqual(outer?.children.count, 1, "one child of the VStack changed")
        let row = outer?.children.first
        XCTAssertEqual(row?.type, .horizontalStackLayout)
        XCTAssertEqual(row?.children.first?.props["text"], .string("x 1"))
    }

    /// And the reading taken inside the braces names the view whose braces
    /// they are, counts the container, and says what it was built for.
    func testAReadingInsideTheRebuiltClosureNamesTheViewAndTheState() {
        let body = Said(), inner = Said()
        let view = Outer(body: body, inner: inner)
        let renders = Renders()

        renders.render(stack([view.body], id: "root"))
        XCTAssertEqual(inner.last, "Outer: 1 build, first time")

        view.$x.wrappedValue = 1
        renders.revisit(changed: changed)

        XCTAssertEqual(inner.last, "Outer: 2 builds, for x")
    }

    /// A read made in the body itself - before any container's braces - makes
    /// the body the reader, and the whole body is built again.
    func testAReadInTheBodyItselfRebuildsTheBody() {
        let body = Said()
        let view = Direct(body: body)
        let renders = Renders()

        renders.render(stack([view.body], id: "root"))

        view.$x.wrappedValue = 1
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(body.count, 2, "the body read `x`")
        XCTAssertEqual(patch.children.first?.children.first?.props["text"], .string("x 1"))
    }
}
