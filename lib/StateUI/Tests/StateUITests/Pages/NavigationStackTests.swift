// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The navigation stack, as Swift describes it.
//
// A NavigationStack puts the whole stack on the wire as its ARRANGED children:
// the root, then one page per element of the bound path, in order. That is the
// whole protocol going out. Coming back there is one report - a pop the user
// COMPLETED - and it truncates the path.
//
import XCTest
@_spi(Host) @testable import StateUI

/// An application's own routes: a typed enum with its parameters as associated
/// values, which is what replaces a route string and a `[String: String]`.
private enum Route: Hashable {
    case detail(String)
    case level(Int)
}

/// The root, named as it comes into the tree - which is the message that brings
/// it, so a stack arrives with its titles.
private struct Root: ContentView {
    @Environment private var page: PageSession

    var content: any View {
        ModifiedContent(node: label("home")).onCreated { page.title = "Home" }
    }
}

/// A pushed page, named for the route it stands for.
private struct Destination: ContentView {
    @Environment private var page: PageSession
    let name: String

    var content: any View {
        ModifiedContent(node: label(name)).onCreated { page.title = name }
    }
}

/// A pushed page that asks the STACK for everything a page can ask of it,
/// written into its session as it comes into the tree.
private struct DressedDestination: ContentView {
    @Environment private var page: PageSession
    let depth: Int

    var content: any View {
        ModifiedContent(node: label("level \(depth)")).onCreated {
            page.title = "Level \(depth)"

            // Non-default values prove that the host must apply the branch;
            // an assertion agreeing with a default could pass without it.
            page.hasNavigationBar = false
            page.hasBackButton = false
            page.backButtonTitle = "Up"
            page.titleView = ModifiedContent(node: label("on the bar"))
        }
    }
}

/// The stack under test, over whatever path is lent to it.
private func stack(_ path: Binding<[Route]>) -> NavigationStack {
    NavigationStack(path) {
        Root()
    } destination: { route in
        switch route {
        case .detail(let name): Destination(name: name)
        case .level(let depth): Destination(name: "level \(depth)")
        }
    }
}

final class NavigationStackTests: XCTestCase {
    // MARK: - What goes out

    /// The stack IS the children: the root, then the path, in order. Nothing
    /// else says where the application is, so there is nothing to disagree.
    func testTheStackIsTheChildrenOfTheNode() {
        let path = State<[Route]>([.detail("first"), .level(2)])
        let patch = Renders().settled(stack(path.projectedValue).body)

        XCTAssertEqual(patch.type, "NavigationStack")
        XCTAssertEqual(patch.children.count, 3, "the root and the two routes")
        XCTAssertEqual(patch.children.map { $0.props["title"] },
                       [.string("Home"), .string("first"), .string("level 2")])
    }

    /// An empty path is the root alone - which is also the only stack a native
    /// NavigationStack cannot be talked out of having.
    func testAnEmptyPathIsTheRootAlone() {
        let path = State<[Route]>([])
        let node = stack(path.projectedValue).body.built

        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children.first?.id, "root")
    }

    /// Identity is the DEPTH and the ROUTE together. Either alone is wrong, and
    /// the two failures are opposite: depth alone hands a pushed page's `@State`
    /// to whatever route replaces it, and the route alone cannot tell two
    /// `.level(2)` pages apart.
    func testAPageIsIdentifiedByItsDepthAndItsRoute() {
        let repeated = State<[Route]>([.level(2), .level(2)])
        let ids = stack(repeated.projectedValue).body.built.children.map { $0.id }

        XCTAssertEqual(Set(ids).count, ids.count,
                       "a route may repeat on a stack, and each page is its own")

        let first = State<[Route]>([.detail("a")])
        let second = State<[Route]>([.detail("b")])

        XCTAssertNotEqual(
            stack(first.projectedValue).body.built.children.last?.id,
            stack(second.projectedValue).body.built.children.last?.id,
            "a different route at the same depth is a different page")
    }

    /// The same route at the same depth is the same page across renders, which
    /// is what lets a page keep its controls, its scroll offset and its state
    /// while the one above it comes and goes.
    func testTheSameRouteAtTheSameDepthIsTheSamePage() {
        let path = State<[Route]>([.detail("a")])

        let before = stack(path.projectedValue).body.built.children.last?.id

        path.wrappedValue.append(.level(9))
        path.wrappedValue.removeLast()

        XCTAssertEqual(stack(path.projectedValue).body.built.children.last?.id, before)
    }

    /// Pushing is appending, and what the host is told is one arranged list -
    /// the order, the count and the removals in one, which is what the wire
    /// already says about children.
    func testPushingAppendsAndRearranges() {
        let path = State<[Route]>([.detail("a")])
        let renders = Renders()

        renders.settled(stack(path.projectedValue).body)

        path.wrappedValue.append(.level(2))
        let patch = renders.settled(stack(path.projectedValue).body)

        XCTAssertTrue(patch.arranged, "the stack changed, so the arrangement is described")
        XCTAssertEqual(patch.children.count, 3)
        XCTAssertTrue(patch.children[0].isEmpty, "the root did not change")
        XCTAssertTrue(patch.children[1].isEmpty, "nor did the page under the new one")
    }

    /// And popping is assigning: no sequence of commands, no hidden state
    /// machine to steer - the stack the host is told about is the stack there
    /// is.
    func testPoppingIsAssigningTheStateYouWant() {
        let path = State<[Route]>([.detail("a"), .level(2), .level(3)])
        let renders = Renders()

        renders.settled(stack(path.projectedValue).body)

        path.wrappedValue = []
        let patch = renders.settled(stack(path.projectedValue).body)

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.count, 1, "the root, and nothing over it")
    }

    // MARK: - The bar

    /// The bar belongs to the stack, not to a page on it, so its properties
    /// ride on the stack's own node.
    func testTheBarIsTheStacksOwnProperty() {
        let path = State<[Route]>([])

        let node = stack(path.projectedValue)
            .barBackgroundColor(Color("#512BD4"))
            .barForegroundColor(.white)
            .body
            .built

        XCTAssertEqual(node.props["barBackgroundColor"], Color("#512BD4").propValue)
        XCTAssertEqual(node.props["barForegroundColor"], Color("#FFFFFF").propValue)
        XCTAssertNil(node.children.first?.built.props["barBackgroundColor"],
                     "and not on the page under it")
    }

    /// The same promise `testEveryModifierIsExercised` makes a control: a
    /// modifier no message carries is one the host can leave out with nothing
    /// failing. The bar tier has no control fixture - this is its cover.
    func testEveryBarModifierIsExercised() throws {
        let path = State<[Route]>([])

        let sent = Set(
            stack(path.projectedValue)
                .barBackgroundColor(.black)
                .barForegroundColor(.white)
                .body
                .built
                .props
                .keys
                .map(\.name))

        let declared = try Fixtures.propertyKeys(in: "BarElement.swift")

        XCTAssertFalse(declared.isEmpty, "the scan found nothing BarElement.swift writes")

        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            BarElement.swift declares \(missing.joined(separator: ", ")), which \
            this test does not write.

            The bar is a page arrangement's, so it has no control fixture - \
            add the modifier here and read it through the host contract.
            """)
    }

    // MARK: - Binary host contract

    /// The whole thing, written down: a stack with its bar painted, a root, and
    /// two pushed pages - one of which asks the stack for everything a page can
    /// ask of it.
    ///
    /// It lives under `pages/` because a navigation page is not a styleable
    /// control.
    func testTheStackIsWrittenDown() throws {
        let path = State<[Route]>([.detail("one"), .level(2)])

        let tree = NavigationStack(path.projectedValue) {
            Root()
        } destination: { route in
            switch route {
            case .detail(let name): Destination(name: name)
            case .level(let depth): DressedDestination(depth: depth)
            }
        }
        .barBackgroundColor(Color("#512BD4"))
        .barForegroundColor(.white)
        .body

        // As the message that brings the pages carries them - with what each
        // wrote into its session on the way in.
        try Fixtures.check(Renders().settled(tree), against: "pages/NavigationStack")
    }

    // MARK: - What comes back

    /// The one report: a pop the USER completed. The payload is the depth
    /// that survived, so the path is truncated to exactly what is on screen.
    func testACompletedPopTruncatesThePath() {
        let path = State<[Route]>([.detail("a"), .level(2)])
        let renders = Renders()

        let patch = renders.settled(stack(path.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["popped"] ?? -1, with: [.number(1)]))
        XCTAssertEqual(path.wrappedValue, [.detail("a")])
    }

    /// A back gesture that walked all the way home says zero, and the path is
    /// emptied - the root is not on the path, so nothing there names it.
    func testAPopAllTheWayHomeEmptiesThePath() {
        let path = State<[Route]>([.detail("a"), .level(2)])
        let renders = Renders()

        let patch = renders.settled(stack(path.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["popped"] ?? -1, with: [.number(0)]))
        XCTAssertEqual(path.wrappedValue, [])
    }

    /// A report only ever SHORTENS the path. One that describes a stack as deep
    /// as the path already is, or deeper, has been overtaken by another pop and
    /// would otherwise put pages BACK - which no report is allowed to do.
    func testAPopReportNeverPutsPagesBack() {
        let path = State<[Route]>([.detail("a")])
        let renders = Renders()

        let patch = renders.settled(stack(path.projectedValue).body)
        let popped = patch.events?["popped"] ?? -1

        XCTAssertTrue(renders.fire(popped, with: [.number(1)]))
        XCTAssertEqual(path.wrappedValue, [.detail("a")], "one deep already")

        XCTAssertTrue(renders.fire(popped, with: [.number(5)]))
        XCTAssertEqual(path.wrappedValue, [.detail("a")], "deeper than anything described")
    }

    /// A payload of the wrong shape leaves the binding alone, the rule every
    /// typed event modifier in this library follows.
    func testAValueOfTheWrongKindLeavesThePathAlone() {
        let path = State<[Route]>([.detail("a"), .level(2)])
        let renders = Renders()

        let patch = renders.settled(stack(path.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["popped"] ?? -1, with: [.string("one")]))
        XCTAssertEqual(path.wrappedValue, [.detail("a"), .level(2)])
    }
}
