// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWeb
import XCTest

/// A shelf the application declares, whose control draws its books itself.
private enum ShelfContract: ElementContract {
    static let nodeType: NodeType = "DrawnTest.Shelf"
    static let tiers: [any Contract.Type] = [ViewContract.self]
    static let members: [any ContractMember] = []
}

/// A book on a shelf, wearing no tier - as a map's marker.
private enum BookContract: ElementContract {
    static let nodeType: NodeType = "DrawnTest.Book"

    /// What the book is called.
    static let title = ElementProperty<Self, String>("title")

    /// The book was opened.
    static let opened = ElementEvent<Self, Void>("opened")

    static let members: [any ContractMember] = [title, opened]
}

/// The Swift half of a book: its node written and heard through its contract.
private struct Book: Element {
    var node: Node

    /// A book called `title`, which is also how the shelf tells it from the others.
    init(_ title: String) {
        node = Node(contract: BookContract.self)
        node.id = title
        node.write(BookContract.title, title)
    }

    func onOpened(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(BookContract.opened, handler)
        return copy
    }
}

/// The Swift half of a shelf, holding its books.
private struct Shelf: ElementView {
    var node = Node(contract: ShelfContract.self)

    init() {}

    init(_ books: [Book]) {
        node.children = books.map(\.node)
    }
}

/// The control the application makes for a shelf - an element of the page drawing the books it is handed.
@MainActor
private final class ShelfControl: WebControl {
    let element = WebPageElement(tag: "test-shelf")

    /// The books it was handed last, in order.
    var books: [WebChild<BookContract>] = []

    /// How many times it was handed its books.
    var handed = 0
}

/// A page with a shelf of books, each heard when opened, and a button taking one away.
private struct Shelving: View {
    @State private var titles = ["Dune", "Emma"]
    @State private var said = "-"

    var body: some View {
        VStack {
            Shelf(titles.map { title in Book(title).onOpened { said = "opened \(title)" } })
            Button("Shorter").onClicked { titles = ["Emma"] }
            Text(said)
        }
    }
}

/// Children an application's control draws itself, through this host's facade: handed whole and typed, each the same
/// child for as long as it lives, each event raised on its own child, and none given an element of its own. A host
/// runs here, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebDrawnChildrenTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    private static func registerShelf() {
        StateUIControls.add(ShelfContract.self, create: { _ in ShelfControl() }) { shelf in
            shelf.children(BookContract.self, members: [BookContract.title, BookContract.opened]) { control, books in
                control.books = books
                control.handed += 1
            }
        }
    }

    /// The control is handed its books in order, typed by member; none stands as an unsupported view, and the host
    /// says it realizes the book and what the registration named.
    func testTheControlIsHandedItsChildrenAndNoneHasAView() throws {
        Self.registerShelf()
        let host = WebRenderer.running { Shelving() }
        let shelf = try XCTUnwrap(host.views(WebHostedView<ShelfControl>.self).first).control

        XCTAssertEqual(shelf.books.map { $0.value(BookContract.title) }, ["Dune", "Emma"])
        XCTAssertEqual(host.views(WebUnsupportedView.self).count, 0)
        let realization = WebRegistrations.registry.realization
        XCTAssertTrue(realization.elements.contains(BookContract.name))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: BookContract.name, owner: BookContract.name, member: "title")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: BookContract.name, owner: BookContract.name, member: "opened")))
    }

    /// An event raised on a child reaches that child's handler; a child taken away leaves the rest the same children.
    func testAChildsEventReachesItsHandlerAndAChildTakenAwayLeavesTheRest() throws {
        Self.registerShelf()
        let host = WebRenderer.running { Shelving() }
        let shelf = try XCTUnwrap(host.views(WebHostedView<ShelfControl>.self).first).control
        let emma = try XCTUnwrap(shelf.books.last)
        let said = { try? WebBrowser.evaluate("e.textContent", on: host.views(WebTextView.self).last?.node ?? 0) }

        emma.reports.raise(BookContract.opened)
        host.settle { said() != "-" }
        XCTAssertEqual(said(), "opened Emma")

        try XCTUnwrap(host.views(WebButtonView.self).first).onClicked()
        host.settle { shelf.books.count == 1 }

        XCTAssertEqual(shelf.books, [emma], "the book left standing is the same child")
        XCTAssertEqual(shelf.handed, 2)
    }
}

extension WebRenderer {
    /// Every view of `type` the tree holds, in order.
    func views<Native: WebDOMView>(_ type: Native.Type) -> [Native] {
        guard let root = runtime.tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: WebDOMView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? WebElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }

    /// Steps until `done` holds, at most 150 steps.
    func settle(until done: () -> Bool) {
        for _ in 0..<150 {
            if done() { return }
            step()
        }
    }
}
