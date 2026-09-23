// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidBorderViewTests: XCTestCase {
    static var allTests: [(String, (AndroidBorderViewTests) -> () throws -> Void)] {
        [
            ("testABorderHoldsItsChildWithinItsPaddingOnItsShape", testABorderHoldsItsChildWithinItsPaddingOnItsShape),
            ("testABackgroundBrushIsDrawnAcrossTheView", testABackgroundBrushIsDrawnAcrossTheView),
        ]
    }

    static let red: UInt32 = 0xFFFF_0000
    static let green: UInt32 = 0xFF00_FF00
    static let blue: UInt32 = 0xFF00_00FF

    /// The child inside the padding, the fill inside the outline, a rounded corner left empty, and what it holds cut to that shape.
    func testABorderHoldsItsChildWithinItsPaddingOnItsShape() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Border {
                    ColorBox(.red)
                }
                .padding(10)
                .background(Color("#00FF00"))
                .stroke(Color("#0000FF"))
                .strokeWidth(2)
                .shape(.roundedRectangle(20))
                .width(100)
                .height(80)
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()

            let border = try XCTUnwrap(host.views(AndroidBorderView.self).first)
            let box = try XCTUnwrap(host.views(AndroidColorBoxView.self).first)
            XCTAssertTrue(border.frame == (0, 0, 200, 160), "\(border.frame)")
            XCTAssertTrue(box.frame == (20, 20, 160, 120), "\(box.frame)")

            let drawn = border.pixels(at: [(100, 1), (100, 10), (1, 1), (100, 80)])
            XCTAssertEqual(drawn, [Self.blue, Self.green, 0, Self.red], drawn.map { String($0, radix: 16) }.description)
            XCTAssertTrue(Java.callBool(border.reference, TestJava.getClipToOutline))
            XCTAssertEqual(border.outlineRadius, 40, accuracy: 0.01)
        }
    }

    /// A gradient runs across the whole view, from its first colour at the start point to its last at the end.
    func testABackgroundBrushIsDrawnAcrossTheView() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Label("")
                    .background(Brush.linearGradient(
                        [GradientStop(Color("#FF0000"), 0), GradientStop(Color("#0000FF"), 1)],
                        startPoint: Point(0, 0),
                        endPoint: Point(1, 0)))
                    .width(100)
                    .height(20)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            host.layOut()

            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)
            let drawn = label.pixels(at: [(0, 20), (199, 20)])
            XCTAssertGreaterThan(drawn[0] >> 16 & 0xFF, 0xF0, String(drawn[0], radix: 16))
            XCTAssertLessThan(drawn[0] & 0xFF, 0x10, String(drawn[0], radix: 16))
            XCTAssertLessThan(drawn[1] >> 16 & 0xFF, 0x10, String(drawn[1], radix: 16))
            XCTAssertGreaterThan(drawn[1] & 0xFF, 0xF0, String(drawn[1], radix: 16))
        }
    }
}
