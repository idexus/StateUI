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
                ColorBox(.red).background(gradient).height(20)
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
