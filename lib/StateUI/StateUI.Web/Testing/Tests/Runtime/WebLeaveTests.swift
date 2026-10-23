// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb
import XCTest

/// An element that leaves the tree lets go of its views, each of which lets go of its DOM element. A host runs
/// here, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebLeaveTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        XCTAssertEqual(try Leaving.outlived(on: WebDriver()), [])
    }

    /// A window closed lets go of every listener its views hung on the page - a box's size followed, a shape's and a
    /// canvas's, a frame read, a list's cells watched for nearness.
    func testAClosedWindowLetsGoOfEveryListenerItsViewsHung() throws {
        WebRenderer.shared?.leave()
        let before = WebRelay.listenerCount
        let gradient = Brush.linearGradient([GradientStop(.red, 0), GradientStop(.blue, 1)])
        let host = WebRenderer.running {
            VStack {
                Rectangle()
                    .fill(.red)
                    .background(gradient)
                    .height(20)
                Rectangle()
                    .fill(gradient)
                    .height(20)
                    .onFrameChanged { _ in }
                Canvas().height(20)
                ItemsView(["one", "two", "three"]) { Text($0) }.height(80)
            }
        }
        host.step()
        XCTAssertGreaterThan(WebRelay.listenerCount, before, "the views hang listeners")

        host.leave()

        XCTAssertEqual(WebRelay.listenerCount, before, "a listener outlived the window that hung it")
    }

    /// A heading keeps its role whether the user taps it or not: one writer says the role, from everything the view
    /// is - a heading, a container tapped, one assistive technology skips.
    func testAHeadingKeepsItsRoleTappedOrNot() throws {
        WebRenderer.shared?.leave()
        let host = WebRenderer.running { VStack { Text("Section") }.accessibilityHeading(.h2).id("heading") }
        host.step()
        let heading = try XCTUnwrap((host.runtime.tree.root?.first(id: .manual("heading"))?.native as? WebElement)?.view)
        let role = { try WebBrowser.evaluate("e.getAttribute('role') ?? ''", on: heading.node) ?? "" }
        XCTAssertEqual(try role(), "heading")

        heading.isTapped = true
        XCTAssertEqual(try role(), "heading", "a tap took the heading's role")
        heading.isTapped = false
        XCTAssertEqual(try role(), "heading", "the tap gone took the role with it")
        host.leave()
    }

    /// A split button lets go of its arrow with itself, and a menu of no entries - never shown - of its popover.
    func testASplitButtonsArrowAndAnEmptyMenuLeaveNothing() throws {
        WebRenderer.shared?.leave()
        let before = (WebDOMView.liveCount, WebRelay.listenerCount)
        let host = WebRenderer.running { Button("Save").onClicked {}.menu(.split) { MenuItem("Save as") } }
        host.step()
        host.leave()
        XCTAssertEqual(WebDOMView.liveCount, before.0, "a split button's arrow outlived it")

        do {
            let menu = WebMenu([])
            menu.show()
        }
        XCTAssertEqual(WebDOMView.liveCount, before.0, "an empty menu's popover outlived it")
        XCTAssertEqual(WebRelay.listenerCount, before.1, "and its listener")
    }

    /// A DOM element's number, let go of, is no other element's: what reaches a view that went - an act that waited -
    /// reaches nothing, not the element made after it.
    func testAReleasedElementsNumberIsNoOneElses() throws {
        WebRenderer.shared?.leave()
        let first = State(wrappedValue: true)
        let second = State(wrappedValue: false)
        let host = WebRenderer.running {
            VStack {
                if first.wrappedValue { Text("Gone") }
                if second.wrappedValue { Text("Come") }
            }
        }
        host.step()
        let gone = try XCTUnwrap(host.views(WebTextView.self).first?.node)

        first.wrappedValue = false
        for _ in 0..<3 { host.step() }
        second.wrappedValue = true
        for _ in 0..<3 { host.step() }
        let come = try XCTUnwrap(host.views(WebTextView.self).first?.node)

        XCTAssertNotEqual(come, gone, "the number of the element that went was made again")
        host.leave()
    }

    /// A page the browser keeps to come back to - its back-forward cache - is hidden, not gone: its window hears no
    /// destroying, and stands again as the browser shows the page.
    func testAPageTheBrowserKeepsIsHiddenNotGone() throws {
        WebRenderer.shared?.leave()
        let host = WebRenderer.running { WindowPhaseText() }
        host.step()
        let phase = { (try? WebBrowser.evaluate("e.textContent", on: host.views(WebTextView.self).first?.node ?? 0)) ?? "" }

        try WebBrowser.run("dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true }))")
        for _ in 0..<5 { host.step() }
        XCTAssertNotEqual(phase(), "destroying", "a page kept for coming back heard its end")

        try WebBrowser.run("dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }))")
        for _ in 0..<5 { host.step() }
        XCTAssertNotEqual(phase(), "destroying")
        host.leave()
    }

    /// A web view lets go, as it leaves, of the address of every document it was written - each its history could
    /// lead back to while it stood.
    func testAWebViewLetsGoOfItsDocumentsAddresses() throws {
        WebRenderer.shared?.leave()
        let document = State(wrappedValue: "<p>One</p>")
        let host = WebRenderer.running { WebView().source(html: document.wrappedValue) }
        host.step()
        let frame = try XCTUnwrap(host.views(WebFrameView.self).first?.named.node)
        let address = { try XCTUnwrap(WebBrowser.evaluate("e.src", on: frame)) }
        let first = try address()
        document.wrappedValue = "<p>Two</p>"
        for _ in 0..<3 { host.step() }
        let second = try address()
        XCTAssertNotEqual(first, second)
        let reads = { (address: String) in
            try WebBrowser.truth(
                "(() => { const r = new XMLHttpRequest(); try { r.open('GET', \(WebBrowser.quoted(address)), false); "
                    + "r.send(); return r.status === 200; } catch { return false; } })()", on: 0)
        }
        XCTAssertTrue(try reads(first), "a document its history leads back to")

        host.leave()

        XCTAssertFalse(try reads(first), "a document's address outlived its web view")
        XCTAssertFalse(try reads(second), "a document's address outlived its web view")
    }

    /// A host that leaves takes off the page - its window, its document, its body, the appearance it follows -
    /// every handler it hung there: another host after it hears each key once.
    func testAHostThatLeavesTakesItsHandlersOffThePage() throws {
        WebRenderer.shared?.leave()
        try WebBrowser.run("""
            const add = EventTarget.prototype.addEventListener, remove = EventTarget.prototype.removeEventListener;
            const page = (t) => t === window || t === document || t === document.body || t instanceof MediaQueryList;
            globalThis.__hung = 0;
            globalThis.__restore = () => {
              EventTarget.prototype.addEventListener = add;
              EventTarget.prototype.removeEventListener = remove;
            };
            EventTarget.prototype.addEventListener = function (...a) { if (page(this)) __hung++; return add.apply(this, a); };
            EventTarget.prototype.removeEventListener = function (...a) { if (page(this)) __hung--; return remove.apply(this, a); };
            """)
        defer { try? WebBrowser.run("__restore()") }
        let host = WebRenderer.running { Text("Shown") }
        host.step()
        XCTAssertGreaterThan(try XCTUnwrap(WebBrowser.number("__hung", on: 0)), 0, "the host hears the page")

        host.leave()

        XCTAssertEqual(try WebBrowser.number("__hung", on: 0), 0, "a handler outlived its host on the page")
    }

    /// A list lets go of the cells of the entries it no longer shows in their order, the same every run.
    func testAListLetsGoOfItsCellsInTheirOrder() throws {
        WebRenderer.shared?.leave()
        let items = State(wrappedValue: (0..<12).map { "Item \($0)" })
        let host = WebRenderer.running { ItemsView(items.wrappedValue) { Text($0) }.height(600) }
        for _ in 0..<4 { host.step() }
        try WebBrowser.run("""
            globalThis.__names = new Map([...document.querySelectorAll('.stateui-item')].map((c) => [c, c.textContent]));
            globalThis.__left = [];
            globalThis.__remove = Element.prototype.remove;
            Element.prototype.remove = function () {
              if (__names.has(this)) __left.push(__names.get(this));
              return __remove.call(this);
            };
            """)
        defer { try? WebBrowser.run("Element.prototype.remove = __remove") }

        items.wrappedValue = ["Item 0"]
        for _ in 0..<3 { host.step() }

        let left = try WebBrowser.evaluate("__left.join('|')", on: 0) ?? ""
        XCTAssertEqual(left, (1..<12).map { "Item \($0)" }.joined(separator: "|"))
        host.leave()
    }

    /// A window closed lets go of every view it made, its bar's with the page's.
    func testAClosedWindowLetsGoOfEveryViewItMade() throws {
        WebRenderer.shared?.leave()
        let before = WebDOMView.liveCount
        let host = WebRenderer.running { Text("Shown") }
        XCTAssertGreaterThan(WebDOMView.liveCount, before, "the window shows its page")

        host.leave()

        XCTAssertEqual(WebDOMView.liveCount, before, "a view of the closed window outlived it")
    }
}

/// The phase of the window it stands in, in words.
private struct WindowPhaseText: View {
    @Environment(\.window) private var window

    var body: some View { Text("\(window.phase)") }
}
