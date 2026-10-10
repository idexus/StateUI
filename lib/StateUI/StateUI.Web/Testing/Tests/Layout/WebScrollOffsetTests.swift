// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// An offset the tree writes moves a scroller as the host layer's rule says - waiting for its first layout, a
/// scroller that scrolls neither way standing at its beginning. The browser lays out, so the suite runs it in a
/// browser (`test-web.sh --browser`).
@MainActor
final class WebScrollOffsetTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAnOffsetWrittenBeforeTheFirstLayoutIsMovedToAfterIt() throws {
        let offset = State(wrappedValue: Point(x: 0, y: 300))
        let host = WebRenderer.running {
            ScrollView { VStack { ForEach(Array(0..<40)) { Text("Row \($0)").height(30) } } }
                .scrollOffset(offset.projectedValue)
                .height(200)
        }
        let scroller = try XCTUnwrap(host.views(WebScrollView.self).first)
        host.settle { (try? WebBrowser.number("e.scrollTop", on: scroller.node)) == 300 }

        XCTAssertEqual(try WebBrowser.number("e.scrollTop", on: scroller.node), 300, "the offset written was lost")
    }

    func testAScrollerThatScrollsNeitherWayStandsAtItsBeginning() throws {
        let orientation = State(wrappedValue: ScrollOrientation.vertical)
        let offset = State(wrappedValue: Point(x: 0, y: 100))
        let host = WebRenderer.running {
            ScrollView { VStack { ForEach(Array(0..<40)) { Text("Row \($0)").height(30) } } }
                .orientation(orientation.projectedValue)
                .scrollOffset(offset.projectedValue)
                .height(200)
        }
        let scroller = try XCTUnwrap(host.views(WebScrollView.self).first)
        host.settle { (try? WebBrowser.number("e.scrollTop", on: scroller.node)) == 100 }

        orientation.wrappedValue = .neither
        host.settle { (try? WebBrowser.number("e.scrollTop", on: scroller.node)) == 0 }

        XCTAssertEqual(try WebBrowser.number("e.scrollTop", on: scroller.node), 0, "it stands where it was scrolled")
    }
}
