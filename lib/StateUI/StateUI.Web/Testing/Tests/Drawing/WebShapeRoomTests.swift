// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWeb
import XCTest

/// A shape has no size of its own: in a stack it takes no room along it, so what follows it stands in the window. The
/// browser lays out, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebShapeRoomTests: XCTestCase {
    override func setUp() {
        WebTestLoop.started
    }

    func testAShapeInAStackTakesNoRoomAlongIt() throws {
        let host = WebRenderer.running { VStack { Ellipse(); Button("Fade") } }
        host.step()
        let shape = try XCTUnwrap(host.views(WebShapeView.self).first)
        let button = try XCTUnwrap(host.views(WebButtonView.self).first)

        let shapeBox = try WebBrowser.evaluate("stateui.box(e).join(' ')", on: shape.node)
        XCTAssertEqual(try WebBrowser.number("e.getBoundingClientRect().height", on: shape.node), 0, shapeBox ?? "")
        XCTAssertTrue(try WebBrowser.truth("e.getBoundingClientRect().width > 0", on: shape.node), "it fills across")
        XCTAssertTrue(
            try WebBrowser.truth("e.getBoundingClientRect().bottom <= innerHeight", on: button.node),
            "the button after it stands in the window")
    }

    func testAShapeFillsTheRoomItsLayoutGivesIt() throws {
        let host = WebRenderer.running { VStack { Rectangle().fill(.red).height(40) } }
        host.step()
        let shape = try XCTUnwrap(host.views(WebShapeView.self).first)

        XCTAssertEqual(try WebBrowser.number("e.querySelector('svg').getBoundingClientRect().height", on: shape.node), 40)
        let drawn = try WebBrowser.evaluate("e.outerHTML", on: shape.node) ?? ""
        XCTAssertTrue(try WebBrowser.truth("e.querySelector('path').getAttribute('d')?.length > 0", on: shape.node), drawn)
    }
}
