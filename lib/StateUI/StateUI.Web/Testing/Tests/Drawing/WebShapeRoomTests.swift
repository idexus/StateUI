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

    /// A figure made of a blur is cut to the figure, the filter's blur with it: over a page of one color, the corner of
    /// an oval's box - outside the oval - shows that color unchanged.
    func testAFigureMadeOfABlurIsCutToItsFigure() throws {
        let host = WebRenderer.running {
            ZStack {
                Fill(.steelBlue)
                Ellipse()
                    .fill(.blur(.thin))
                    .width(80)
                    .height(80)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            .width(200)
            .height(120)
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        host.step()
        let shape = try XCTUnwrap(host.views(WebShapeView.self).first)
        let box = (try WebBrowser.evaluate("stateui.box(e).join(',')", on: shape.node) ?? "")
            .split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(box.count, 4)

        let page = pixel(x: box[0] + 150, y: box[1] + 60)
        XCTAssertEqual(pixel(x: box[0] + 3, y: box[1] + 3), page, "the corner outside the oval: the page's own color")
        XCTAssertNotEqual(pixel(x: box[0] + 40, y: box[1] + 40), page, "the oval's middle: the blur's color over it")
    }

    /// The window picture's channels at a point of the page.
    private func pixel(x: Double, y: Double) -> [Int] {
        (WebBrowser.ask([("pixel", .points([Point(x: x, y: y)]))]) ?? "").split(separator: ",").compactMap { Int($0) }
    }

    /// A LATER CHILD DRAWS OVER A SHAPE BEFORE IT: in a grid's one cell the view after the shape stands over it, as a
    /// layout draws its children in their order - the shape's own drawing standing over its box notwithstanding.
    func testALaterChildDrawsOverAShapeBeforeIt() throws {
        let host = WebRenderer.running {
            Grid {
                Rectangle()
                    .fill(.red)
                    .width(100)
                    .height(100)
                Text("Over")
                    .background(.blue)
                    .width(100)
                    .height(100)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        host.step()
        let shape = try XCTUnwrap(host.views(WebShapeView.self).first)
        let box = (try WebBrowser.evaluate("stateui.box(e).join(',')", on: shape.node) ?? "")
            .split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(box.count, 4)

        let middle = pixel(x: box[0] + 80, y: box[1] + 80)
        XCTAssertGreaterThan(middle[2], middle[0], "the later child's blue over the shape's red: \(middle)")
    }

    func testAShapeFillsTheRoomItsLayoutGivesIt() throws {
        let host = WebRenderer.running { VStack {
            Rectangle()
                .fill(.red)
                .height(40)
        } }
        host.step()
        let shape = try XCTUnwrap(host.views(WebShapeView.self).first)

        XCTAssertEqual(try WebBrowser.number("e.querySelector('svg').getBoundingClientRect().height", on: shape.node), 40)
        let drawn = try WebBrowser.evaluate("e.outerHTML", on: shape.node) ?? ""
        XCTAssertTrue(try WebBrowser.truth("e.querySelector('path').getAttribute('d')?.length > 0", on: shape.node), drawn)
    }
}
