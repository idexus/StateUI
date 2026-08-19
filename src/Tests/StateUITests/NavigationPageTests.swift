// The navigation stack, as Swift describes it.
//
// A NavigationPage puts the whole stack on the wire as its ARRANGED children:
// the root, then one page per element of the bound path, in order. That is the
// whole protocol going out. Coming back there is one report - a pop the reader
// COMPLETED - and it truncates the path.
//
// What the renderer does with the arrangement is next door, in the C#
// NavigationPageTests.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// An application's own routes: a typed enum with its parameters as associated
/// values, which is what replaces a route string and a `[String: String]`.
private enum Route: Hashable {
    case detail(String)
    case level(Int)
}

private struct Root: ContentPage {
    var title: String? { "Home" }
    var content: Element { label("home") }
}

private struct Destination: ContentPage {
    let name: String

    var title: String? { name }
    var content: Element { label(name) }
}

/// A pushed page that asks the STACK for everything a page can ask of it - the
/// attached properties, spelled with the class that declares them.
private struct DressedDestination: ContentPage {
    let depth: Int

    var title: String? { "Level \(depth)" }
    var content: Element { label("level \(depth)") }

    // Every one of these says the OPPOSITE of MAUI's own default, deliberately:
    // an assertion that agrees with the default cannot fail, so the whole
    // branch that applies it could be deleted with the tests still green.
    var navigationPageHasNavigationBar: Bool? { false }
    var navigationPageHasBackButton: Bool? { false }
    var navigationPageBackButtonTitle: String? { "Up" }
    var navigationPageTitleIconImageSource: ImageSource? { ImageSource("mark.png") }
    var navigationPageIconColor: Color? { .white }
    var navigationPageTitleView: Element? { label("on the bar") }
}

/// The stack under test, over whatever path is lent to it.
private func stack(_ path: Binding<[Route]>) -> NavigationPage {
    NavigationPage(path) {
        Root()
    } destination: { route in
        switch route {
        case .detail(let name): Destination(name: name)
        case .level(let depth): Destination(name: "level \(depth)")
        }
    }
}

final class NavigationPageTests: XCTestCase {
    // MARK: - What goes out

    /// The stack IS the children: the root, then the path, in order. Nothing
    /// else says where the application is, so there is nothing to disagree.
    func testTheStackIsTheChildrenOfTheNode() {
        let path = State<[Route]>([.detail("first"), .level(2)])
        let node = stack(path.projectedValue).body.built

        XCTAssertEqual(node.type, "NavigationPage")
        XCTAssertEqual(node.children.count, 3, "the root and the two routes")
        XCTAssertEqual(node.children.map { $0.built.props["title"] },
                       [.string("Home"), .string("first"), .string("level 2")])
    }

    /// An empty path is the root alone - which is also the only stack a native
    /// NavigationPage cannot be talked out of having.
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

        renders.render(stack(path.projectedValue).body)

        path.wrappedValue.append(.level(2))
        let patch = renders.render(stack(path.projectedValue).body)

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

        renders.render(stack(path.projectedValue).body)

        path.wrappedValue = []
        let patch = renders.render(stack(path.projectedValue).body)

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.count, 1, "the root, and nothing over it")
    }

    // MARK: - The bar

    /// The bar belongs to the STACK, not to a page on it - MAUI declares all
    /// three on the interface `NavigationPage` and `TabbedPage` share, so they
    /// ride on the stack's own node.
    func testTheBarIsTheStacksOwnProperty() {
        let path = State<[Route]>([])

        let node = stack(path.projectedValue)
            .barBackgroundColor(Color.fromArgb("#512BD4"))
            .barTextColor(.white)
            .body
            .built

        XCTAssertEqual(node.props["barBackgroundColor"], Color("#512BD4").propValue)
        XCTAssertEqual(node.props["barTextColor"], Color("#FFFFFF").propValue)
        XCTAssertNil(node.children.first?.built.props["barBackgroundColor"],
                     "and not on the page under it")
    }

    /// A brush instead of a colour, for a bar that is a gradient.
    func testTheBarCanBeABrush() {
        let path = State<[Route]>([])

        let node = stack(path.projectedValue)
            .barBackground(.linearGradient([GradientStop(.black, 0), GradientStop(.white, 1)]))
            .body
            .built

        XCTAssertNotNil(node.props["barBackground"])
    }

    /// The same promise `testEveryModifierIsExercised` makes a control: a
    /// modifier no message carries is one the host can leave out with nothing
    /// failing. The bar tier has no control fixture - this is its cover.
    func testEveryBarModifierIsExercised() throws {
        let path = State<[Route]>([])

        let sent = Set(
            stack(path.projectedValue)
                .barBackgroundColor(.black)
                .barBackground(.solidColor(.white))
                .barTextColor(.white)
                .body
                .built
                .props
                .keys
                .map(\.name))

        let declared = try Fixtures.propertyKeys(in: "BarElement.swift")
        let missing = declared.subtracting(sent).sorted()

        XCTAssertTrue(missing.isEmpty, """
            BarElement.swift declares \(missing.joined(separator: ", ")), which \
            this test does not write.

            The bar is a page arrangement's, so it has no control fixture - \
            add the modifier here and read it on the C# side.
            """)
    }

    // MARK: - The contract the C# side reads

    /// The whole thing, written down: a stack with its bar painted, a root, and
    /// two pushed pages - one of which asks the stack for everything a page can
    /// ask of it.
    ///
    /// Kept under `pages/` rather than `controls/`, deliberately: a fixture in
    /// `controls/` is walked by the C# StyleTests, which would then insist that
    /// every property in it can be set by a Style - and a page's cannot, there
    /// being no page arm in SwiftStyles at all.
    func testTheStackIsWrittenDown() throws {
        let path = State<[Route]>([.detail("one"), .level(2)])
        let differ = Differ()

        let tree = NavigationPage(path.projectedValue) {
            Root()
        } destination: { route in
            switch route {
            case .detail(let name): Destination(name: name)
            case .level(let depth): DressedDestination(depth: depth)
            }
        }
        .barBackgroundColor(Color.fromArgb("#512BD4"))
        .barBackground(.linearGradient([GradientStop(.black, 0), GradientStop(.white, 1)]))
        .barTextColor(.white)
        .body

        let result = differ.reconcile(nil, with: tree)
        let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "pages/NavigationPage")
    }

    // MARK: - What comes back

    /// The one report: a pop the READER completed. The payload is the depth
    /// that survived, so the path is truncated to exactly what is on screen.
    func testACompletedPopTruncatesThePath() {
        let path = State<[Route]>([.detail("a"), .level(2)])
        let renders = Renders()

        let patch = renders.render(stack(path.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["popped"] ?? -1, with: [.number(1)]))
        XCTAssertEqual(path.wrappedValue, [.detail("a")])
    }

    /// A back gesture that walked all the way home says zero, and the path is
    /// emptied - the root is not on the path, so nothing there names it.
    func testAPopAllTheWayHomeEmptiesThePath() {
        let path = State<[Route]>([.detail("a"), .level(2)])
        let renders = Renders()

        let patch = renders.render(stack(path.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["popped"] ?? -1, with: [.number(0)]))
        XCTAssertEqual(path.wrappedValue, [])
    }

    /// A report only ever SHORTENS the path. One that describes a stack as deep
    /// as the path already is, or deeper, has been overtaken by another pop and
    /// would otherwise put pages BACK - which no report is allowed to do.
    func testAPopReportNeverPutsPagesBack() {
        let path = State<[Route]>([.detail("a")])
        let renders = Renders()

        let patch = renders.render(stack(path.projectedValue).body)
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

        let patch = renders.render(stack(path.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["popped"] ?? -1, with: [.string("one")]))
        XCTAssertEqual(path.wrappedValue, [.detail("a"), .level(2)])
    }
}
