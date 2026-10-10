// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWeb
import XCTest

/// A shape has no size of its own: in a stack it takes no room along it, so what follows it stands in the window; it
/// fills the room its layout gives it, and its gradient lies over that room. The browser lays out, so the suite runs
/// it in a browser (`test-web.sh --browser`).
@MainActor
final class WebShapeRoomTests: XCTestCase {
    override func setUp() async throws {
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

    /// A shape's gradient lies over its room, whatever the geometry's own units: a path drawn ten units wide and
    /// placed over a room a hundred wide is red at its left edge and blue at its right.
    func testAShapesGradientLiesOverItsRoom() throws {
        let across = Brush.linearGradient(
            [GradientStop(.red, 0), GradientStop(.blue, 1)], startPoint: Point(0, 0.5), endPoint: Point(1, 0.5))
        let host = WebRenderer.running {
            VStack { Path("M0 0 H10 V10 H0 Z").fill(across).contentMode(.fill).width(100).height(100) }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
        }
        host.step()
        let shape = try XCTUnwrap(host.views(WebShapeView.self).first)
        let box = (try WebBrowser.evaluate("stateui.box(e).join(',')", on: shape.node) ?? "")
            .split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(box.count, 4)

        let left = pixel(x: box[0] + 5, y: box[1] + 50), right = pixel(x: box[0] + 95, y: box[1] + 50)
        XCTAssertGreaterThan(left[0], left[2], "red at the left edge: \(left)")
        XCTAssertGreaterThan(right[2], right[0], "blue at the right edge: \(right)")
    }

    /// The window picture's channels at a point of the page.
    private func pixel(x: Double, y: Double) -> [Int] {
        (WebBrowser.ask([("pixel", .points([Point(x: x, y: y)]))]) ?? "").split(separator: ",").compactMap { Int($0) }
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
