// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a Window puts on the wire.
//
// A window declares its page, its title bar and its modal stack; what it is
// called, where it stands, how big it is and where it is in its life are its
// SESSION's - state a view in it writes and reads - carried on the window node
// under MAUI's property names and units. Everything here is about the SHAPE
// that arrives, and what the renderer does with it is next door, in the C#
// WindowTests.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

/// A window as an author declares one: a page, and nothing else - what it is
/// told, a title bar included, being its session's.
private struct PlainWindow: Window {
    var page: any Page { Home() }
}

private struct Home: ContentPage {
    var content: any View { ModifiedContent(node: label("home")) }
}

/// The C# example from MAUI's own documentation, written on a window's
/// session.
private func desktop() -> WindowSession {
    let session = WindowSession()
    session.title = "My Application"
    session.width = 1200
    session.height = 800
    session.minimumWidth = 600
    session.minimumHeight = 400
    session.x = 100
    session.y = 100
    return session
}

final class WindowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    /// Every property is MAUI's, camelCased, and nothing else is invented.
    func testAWindowCarriesTheMauiPropertyNames() {
        let node = PlainWindow().body(panel: nil, session: desktop()).built

        XCTAssertEqual(node.type, "Window")
        XCTAssertEqual(node.props["title"], .string("My Application"))
        XCTAssertEqual(node.props["width"], .number(1200))
        XCTAssertEqual(node.props["height"], .number(800))
        XCTAssertEqual(node.props["minimumWidth"], .number(600))
        XCTAssertEqual(node.props["minimumHeight"], .number(400))
        XCTAssertEqual(node.props["x"], .number(100))
        XCTAssertEqual(node.props["y"], .number(100))
    }

    /// The title bar rides as a CHILD of the window, read by type the way the
    /// resources are - and it is one PROPERTY of the window's session, so a
    /// window has one or none and there is nothing to double.
    func testAWindowCarriesItsTitleBarAsAChild() {
        let session = WindowSession()
        session.titleBar = TitleBar("StateUI")
            .subtitle("Home")
            .leadingContent { label("lead") }

        let node = PlainWindow().body(panel: nil, session: session).built

        let bars = node.children.filter { $0.type == "TitleBar" }

        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars.first?.props["title"], .string("StateUI"))
        XCTAssertEqual(bars.first?.props["subtitle"], .string("Home"))
        XCTAssertEqual(bars.first?.children.first?.type, "LeadingContent")
    }

    /// A slot takes a BUILDER, so the two branches of an `if` inside one are
    /// two elements - the same rule that holds inside a `VStack`.
    ///
    /// A slot taking a plain `() -> Element` would be nested content without
    /// a builder: nothing inside it would have a branch key, an `if/else`
    /// there would describe ONE control merely changing its properties, and
    /// the reader's focus and caret would go on living in a control the author
    /// had written as switched away from.
    func testTheTwoBranchesOfAnIfInASlotAreDifferentElements() {
        let session = WindowSession()

        // The bar written into the window's session, and the window over it -
        // the window is the reader of its bar, so a bar written again is the
        // window built again.
        func tree(editing: Bool) -> Node {
            session.titleBar = TitleBar("StateUI")
                .content {
                    if editing {
                        Entry("name")
                    } else {
                        Entry("nickname")
                    }
                }

            return PlainWindow().body(panel: nil, session: session)
        }

        let renders = Renders()

        let name = entry(in: renders.render(tree(editing: true)))
        let nickname = entry(in: renders.render(
            tree(editing: false), changed: Renderer.shared.pendingChanges))

        XCTAssertNotNil(name)
        XCTAssertNotNil(nickname)
        XCTAssertNotEqual(name, nickname, "both branches were given one control to share")
    }

    /// A slot whose closure produces nothing carries NO WRAPPER NODE, which is
    /// what empties it: the host reads a slot's leaving as its wrapper's
    /// absence from an arranged list, and a wrapper arriving with no children
    /// is a patch about a slot whose view did not change.
    func testASlotThatProducesNothingIsEmptied() {
        func bar(showing: Bool) -> Node {
            TitleBar("StateUI")
                .trailingContent {
                    if showing {
                        Button("Account")
                    }
                }
                .body
                .built
        }

        XCTAssertEqual(bar(showing: true).children.map(\.type), ["TrailingContent"])
        XCTAssertEqual(bar(showing: false).children.map(\.type), [])
    }

    /// The other half of that promise is the PATCH: when the slot's `if` flips
    /// off, the wrapper's leaving rides the wire as an arranged children list
    /// that no longer carries it - an absent field means unchanged, so only
    /// the arrangement can say "gone".
    func testASlotThatEmptiesRidesThePatchAsAnArrangedRemoval() {
        let renders = Renders()

        func bar(showing: Bool) -> Node {
            TitleBar("StateUI")
                .leadingContent {
                    if showing {
                        Button("Menu")
                    }
                }
                .body
                .built
        }

        renders.render(bar(showing: true))
        let patch = renders.render(bar(showing: false))

        XCTAssertTrue(patch.arranged, "the slot left, so the children are said whole")
        XCTAssertFalse(patch.children.contains { $0.type == "LeadingContent" },
                       "the wrapper is absent, which is what empties the slot")
    }

    /// The identity of the first Entry a patch mentions, at any depth.
    private func entry(in patch: Patch) -> ElementId? {
        if patch.type == "Entry" { return patch.id }

        for child in patch.children {
            if let hit = entry(in: child) { return hit }
        }

        return nil
    }

    /// The maximum has to be there as well: MAUI declares both ends, and a
    /// property missing from one of them is a gap somebody has to work around.
    func testAWindowCanBeGivenAMaximumToo() {
        let session = WindowSession()
        session.maximumWidth = 1600
        session.maximumHeight = 1200

        let node = PlainWindow().body(panel: nil, session: session).built

        XCTAssertEqual(node.props["maximumWidth"], .number(1600))
        XCTAssertEqual(node.props["maximumHeight"], .number(1200))
    }

    /// A window whose session says nothing about its size sends nothing about
    /// its size, which is what leaves the platform's own default in place -
    /// and, on a phone, what keeps a desktop property from arriving where it
    /// means nothing.
    func testAWindowSendsOnlyWhatItsSessionWasGiven() {
        let session = WindowSession()
        session.title = "Plain"

        let node = PlainWindow().body(panel: nil, session: session).built

        XCTAssertEqual(node.propNames, ["title"])
    }

    /// The page is still the child, whatever else the window carries - the
    /// window's own properties change the window, never what is in it.
    func testThePropertiesLeaveThePageAlone() throws {
        let node = PlainWindow().body(panel: nil, session: desktop()).built

        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(try XCTUnwrap(node.children.first).type, "ContentPage")
    }

    /// A number crosses as a double's own bits - nothing formatted, nothing
    /// parsed - and the probe reads the exact values back off the wire.
    func testTheSizeCrossesAsItsOwnBits() {
        let patch = Renders().render(PlainWindow().body(panel: nil, session: desktop()))
        let root = WireProbe.decodeMessage(
            Wire.encode(patch, generation: 1, dictionary: WireDictionary()),
            names: WireNames()).root

        let props = Dictionary(uniqueKeysWithValues: root.props.map { ($0.key, $0.value) })
        XCTAssertEqual(props["width"], .number(1200))
        XCTAssertEqual(props["minimumHeight"], .number(400))
    }

    /// A window resized through its session is a property change like any
    /// other: the window is the reader of what it was told, so the message
    /// names the window and the one property, not the page under it.
    func testResizingTheWindowSendsOnlyTheWindow() {
        let session = WindowSession()
        session.width = 1200

        let renders = Renders()
        renders.render(PlainWindow().body(panel: nil, session: session))

        session.width = 1400

        let patch = renders.render(
            PlainWindow().body(panel: nil, session: session),
            changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(patch.propNames, ["width"])
        XCTAssertEqual(patch.children.count, 0)
    }

    /// The window node carries the six moments of its life - MAUI's Window
    /// event names, camelCased - so the host's window reports with them.
    func testAWindowsLifetimeRidesAsItsEvents() {
        let patch = Renders().render(PlainWindow().body(panel: nil, session: WindowSession()))

        XCTAssertEqual(
            patch.events?.keys.sorted(),
            ["activated", "created", "deactivated", "destroying", "resumed", "stopped"])
    }

    /// A moment the platform reports moves the session's phase, in the order
    /// the platform says them.
    func testAMomentTheWindowReportsMovesItsPhase() throws {
        let session = WindowSession()
        let renders = Renders()

        let patch = renders.render(PlainWindow().body(panel: nil, session: session))
        let events = try XCTUnwrap(patch.events)

        XCTAssertTrue(renders.fire(try XCTUnwrap(events["stopped"])))
        XCTAssertEqual(session.phase, .stopped)

        XCTAssertTrue(renders.fire(try XCTUnwrap(events["resumed"])))
        XCTAssertEqual(session.phase, .resumed)
    }
}

private extension Node {
    /// The property names this node carries, sorted - the same convenience the
    /// patches have.
    var propNames: [String] { props.keys.map(\.name).sorted() }
}
