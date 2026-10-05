// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// The pointers pressed on a view: one dragged past its distance, two pinched by how far apart they stand.
final class WebPressTests: XCTestCase {
    private let corner = Point(x: 100, y: 100)
    private let size = LayoutSize(width: 200, height: 200)

    /// A mouse's press is a drag once it moves more than four points, measured from where it went down; its click
    /// is then no tap.
    func testAMousePressMovedFarEnoughIsADrag() {
        var press = WebPress()
        XCTAssertEqual(press.down(1, at: Point(x: 150, y: 150), kind: 0, origin: corner, size: size), [])
        XCTAssertEqual(press.moved(1, to: Point(x: 153, y: 150), origin: corner, size: size), [])
        XCTAssertEqual(press.moved(1, to: Point(x: 160, y: 155), origin: corner, size: size),
                       [.drag(.began, x: 0, y: 0), .drag(.changed, x: 10, y: 5)])
        XCTAssertEqual(press.up(1, letGo: true, origin: corner, size: size), [.drag(.ended, x: 10, y: 5)])
        XCTAssertTrue(press.wasDragged)
        _ = press.down(1, at: Point(x: 150, y: 150), kind: 0, origin: corner, size: size)
        XCTAssertFalse(press.wasDragged, "a new press is no drag yet")
    }

    /// A second finger takes the press from its drag to a pinch: the scale each step is how far apart the fingers
    /// stand against the step before, where their middle is in the view.
    func testASecondFingerPinches() {
        var press = WebPress()
        _ = press.down(1, at: Point(x: 180, y: 200), kind: 2, origin: corner, size: size)
        _ = press.moved(1, to: Point(x: 160, y: 200), origin: corner, size: size)
        XCTAssertEqual(press.down(2, at: Point(x: 240, y: 200), kind: 2, origin: corner, size: size),
                       [.drag(.cancelled, x: -20, y: 0), .pinch(.began, scale: 1, at: Point(x: 0.5, y: 0.5))])
        XCTAssertEqual(press.moved(2, to: Point(x: 320, y: 200), origin: corner, size: size),
                       [.pinch(.changed, scale: 2, at: Point(x: 0.7, y: 0.5))])
        XCTAssertEqual(press.up(2, letGo: true, origin: corner, size: size),
                       [.pinch(.ended, scale: 1, at: Point(x: 0.7, y: 0.5))])
    }
}
