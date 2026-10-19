// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// A canvas as the browser draws it, at the screen's own density. The browser lays out and draws, so the suite runs
/// it in a browser (`test-web.sh --browser`).
@MainActor
final class WebCanvasViewTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A CANVAS STANDS AT THE SCREEN'S DENSITY AS IT TURNS: a window moved to a denser screen draws it again, as
    /// many pixels to a point as that screen has. The window's width turns with it: Chrome's emulated density alone
    /// tells no media query.
    func testACanvasIsDrawnAgainAtANewDensity() throws {
        let host = WebRenderer.running {
            Canvas {
                Draw.fillColor(.blue)
                Draw.fillRectangle(x: 0, y: 0, width: 40, height: 40)
            }
            .width(100)
            .height(50)
        }
        host.step()
        let canvas = try XCTUnwrap(host.views(WebCanvasView.self).first?.node)
        let pixels = "e.querySelector('canvas').width"
        XCTAssertEqual(try WebBrowser.number(pixels, on: canvas), 100)
        defer { WebBrowser.ask([("density", .number(1))]) }

        WebBrowser.ask([("density", .number(2)), ("width", .number(1000))])
        for _ in 0..<10 { host.step() }

        XCTAssertEqual(try WebBrowser.number(pixels, on: canvas), 200, "the canvas kept the density it was drawn at")
        host.leave()
    }
}
