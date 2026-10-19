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
                Rectangle().fill(.red).background(gradient).height(20)
                Rectangle().fill(gradient).height(20).onFrameChanged { _ in }
                Canvas().height(20)
                ItemsView(["one", "two", "three"]) { Text($0) }.height(80)
            }
        }
        host.step()
        XCTAssertGreaterThan(WebRelay.listenerCount, before, "the views hang listeners")

        host.leave()

        XCTAssertEqual(WebRelay.listenerCount, before, "a listener outlived the window that hung it")
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
