// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a Window puts on the host boundary.
//
// A window declares its page, its title bar and its modal stack; what it is
// called, where it stands, how big it is and where it is in its life are its
// SESSION's - state a view in it writes and reads - carried on the window node
// under StateUI's property names and units. Everything here is about the
// shape that arrives; a native host suite verifies how it is presented.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// A window as an author declares one: a page, and nothing else - what it is
/// told, a title bar included, being its session's.
private struct PlainWindow: Window {
    var page: any Page { Home() }
}

private struct Home: ContentView {
    var content: any View { ModifiedContent(node: label("home")) }
}

/// A page laying a banner over its window while a state says so, and a field under it always.
private struct Noticed: ContentView {
    let banner: State<Bool>

    var content: any View {
        let banner = banner
        return ModifiedContent(node: label("home")).overlays {
            if banner.wrappedValue { ModifiedContent(node: label("banner")) }
            TextField("toast")
        }
    }
}

/// A desktop-sized window session used to verify the complete authored shape.
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

    /// Every authored session property keeps its StateUI spelling and value.
    func testAWindowCarriesItsSessionProperties() {
        let node = PlainWindow().body(session: desktop()).built

        XCTAssertEqual(node.type, "Window")
        XCTAssertEqual(node.props["title"], .string("My Application"))
        XCTAssertEqual(node.props["width"], .number(1200))
        XCTAssertEqual(node.props["height"], .number(800))
        XCTAssertEqual(node.props["minimumWidth"], .number(600))
        XCTAssertEqual(node.props["minimumHeight"], .number(400))
        XCTAssertEqual(node.props["x"], .number(100))
        XCTAssertEqual(node.props["y"], .number(100))
    }

    /// The bar's title area and colours are values an arrangement declares on itself - no child of the window and
    /// nothing in its session.
    func testAnArrangementDeclaresItsBarAsValues() {
        let node = SplitView(State(wrappedValue: true).projectedValue) {
            ModifiedContent(node: label("menu"))
        } detail: {
            ModifiedContent(node: label("detail"))
        }
        .barTitle("StateUI")
        .barSubtitle("Home")
        .barIcon("mark.png")
        .barBackgroundColor(.steelBlue)
        .barForegroundColor(.white)
        .body

        XCTAssertEqual(node.props["barTitle"], .string("StateUI"))
        XCTAssertEqual(node.props["barSubtitle"], .string("Home"))
        XCTAssertEqual(node.props["barIcon"], .string("mark.png"))
        XCTAssertNotNil(node.props["barBackgroundColor"])
        XCTAssertNotNil(node.props["barForegroundColor"])
        XCTAssertEqual(node.children.count, 2, "its two pages alone: values, not declarations")
    }

    /// What a view lays over its window is one declaration after its own children: an overlay holding one ZStack
    /// of the views in the order written, letting a click beside them through. A window lays none of its own until
    /// its scene's inspector docks in it.
    func testAViewDeclaresItsOverlaysInOneStack() throws {
        XCTAssertFalse(PlainWindow().body(session: WindowSession()).built.children.contains { $0.type == .overlay })

        let node = ModifiedContent(node: label("home")).overlays {
            ModifiedContent(node: label("banner"))
            ModifiedContent(node: label("toast"))
        }.body

        let overlay = try XCTUnwrap(node.children.last)
        XCTAssertEqual(overlay.type, .overlay)
        let layers = try XCTUnwrap(overlay.children.first)
        XCTAssertEqual(layers.type, .zStack)
        XCTAssertEqual(layers.props["letsInputThrough"], .bool(true))
        XCTAssertEqual(layers.children.map { $0.props["text"] }, [.string("banner"), .string("toast")])
    }

    /// An overlay keeps its element as another comes and goes: the one standing second stays itself as the first is
    /// taken away.
    func testAnOverlayKeepsItsElementAsAnotherGoes() {
        let banner = State(wrappedValue: true)
        let renders = Renders()

        let both = entry(in: renders.render(Noticed(banner: banner).body))

        banner.wrappedValue = false
        let alone = entry(in: renders.render(Noticed(banner: banner).body, changed: Renderer.shared.pendingChanges))

        XCTAssertNotNil(both)
        XCTAssertEqual(both, alone)
    }

    /// A declaration takes a BUILDER, so the two branches of an `if` inside one are two elements - the same rule
    /// that holds inside a `VStack`. A plain `() -> Element` would give nothing inside a branch key, and the user's
    /// focus and caret would live on in a control the author had switched away from.
    func testTheTwoBranchesOfAnIfInADeclarationAreDifferentElements() {
        func tree(editing: Bool) -> Node {
            ModifiedContent(node: label("home"))
                .titleView {
                    if editing {
                        TextField("name")
                    } else {
                        TextField("nickname")
                    }
                }
                .body
        }

        let renders = Renders()

        let name = entry(in: renders.render(tree(editing: true)))
        let nickname = entry(in: renders.render(
            tree(editing: false), changed: Renderer.shared.pendingChanges))

        XCTAssertNotNil(name)
        XCTAssertNotNil(nickname)
        XCTAssertNotEqual(name, nickname, "both branches were given one control to share")
    }

    /// The identity of the first TextField a patch mentions, at any depth.
    private func entry(in patch: HostPatch) -> ElementId? {
        if patch.type == "TextField" { return patch.id }

        for child in patch.children {
            if let hit = entry(in: child) { return hit }
        }

        return nil
    }

    /// The maximum has to be there as well: a window has both ends, and a
    /// property missing from one of them is a gap somebody has to work around.
    func testAWindowCanBeGivenAMaximumToo() {
        let session = WindowSession()
        session.maximumWidth = 1600
        session.maximumHeight = 1200

        let node = PlainWindow().body(session: session).built

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

        let node = PlainWindow().body(session: session).built

        XCTAssertEqual(node.propNames, ["title"])
    }

    /// The page is still the child, whatever else the window carries - the
    /// window's own properties change the window, never what is in it.
    func testThePropertiesLeaveThePageAlone() throws {
        let node = PlainWindow().body(session: desktop()).built

        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(try XCTUnwrap(node.children.first).type, "Page")
    }

    /// The size a session says is the window's own properties, exactly the
    /// numbers written.
    func testTheSessionsSizeIsTheWindowsProperties() {
        let patch = Renders().render(PlainWindow().body(session: desktop()))

        XCTAssertEqual(patch.props["width"], .number(1200))
        XCTAssertEqual(patch.props["minimumHeight"], .number(400))
    }

    /// A window resized through its session is a property change like any
    /// other: the window is the reader of what it was told, so the message
    /// names the window and the one property, not the page under it.
    func testResizingTheWindowSendsOnlyTheWindow() {
        let session = WindowSession()
        session.width = 1200

        let renders = Renders()
        renders.render(PlainWindow().body(session: session))

        session.width = 1400

        let patch = renders.render(
            PlainWindow().body(session: session),
            changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(patch.propNames, ["width"])
        XCTAssertEqual(patch.children.count, 0)
    }

    /// The window node carries the six moments of its life as its events, so
    /// the host's window reports with them.
    func testAWindowsLifetimeRidesAsItsEvents() {
        let patch = Renders().render(PlainWindow().body(session: WindowSession()))

        XCTAssertEqual(
            patch.events?.keys.sorted(),
            ["activated", "created", "deactivated", "destroying", "resumed", "stopped"])
    }

    /// A moment the platform reports moves the session's phase, in the order
    /// the platform says them.
    func testAMomentTheWindowReportsMovesItsPhase() throws {
        let session = WindowSession()
        let renders = Renders()

        let patch = renders.render(PlainWindow().body(session: session))
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
