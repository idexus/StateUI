// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidColorBoxViewTests: XCTestCase {
    static var allTests: [(String, (AndroidColorBoxViewTests) -> () throws -> Void)] {
        [
            ("testABoxDrawsItsColourWithinItsCornersOverItsBackground", testABoxDrawsItsColourWithinItsCornersOverItsBackground),
            ("testABoxAsksForNoRoom", testABoxAsksForNoRoom),
        ]
    }

    /// One rounded corner, the bottom left, shows the background there and nowhere else.
    func testABoxDrawsItsColourWithinItsCornersOverItsBackground() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                ColorBox(Color("#FF0000"))
                    .cornerRadius(topLeft: 0, topRight: 0, bottomLeft: 20, bottomRight: 0)
                    .background(Color("#00FF00"))
                    .width(100)
                    .height(100)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            host.layOut()

            let box = try XCTUnwrap(host.views(AndroidColorBoxView.self).first)
            let drawn = box.pixels(at: [(1, 198), (198, 198), (1, 1), (100, 100)])
            XCTAssertEqual(
                drawn, [0xFF00_FF00, 0xFFFF_0000, 0xFFFF_0000, 0xFFFF_0000], drawn.map { String($0, radix: 16) }.description)
        }
    }

    /// A box shows nothing of its own: without a size, a start-aligned box in a stack is as narrow as can be.
    func testABoxAsksForNoRoom() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    ColorBox(.red).height(10).horizontalAlignment(.start)
                }
            }
            host.layOut()

            let box = try XCTUnwrap(host.views(AndroidColorBoxView.self).first)
            XCTAssertTrue(box.frame == (0, 0, 0, 20), "\(box.frame)")
        }
    }
}
