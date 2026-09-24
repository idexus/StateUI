// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidCanvasViewTests: XCTestCase {
    static var allTests: [(String, (AndroidCanvasViewTests) -> () throws -> Void)] {
        [
            ("testTheInstructionsDrawInPointsAndInOrder", testTheInstructionsDrawInPointsAndInOrder),
            ("testAFilledArcIsAWedge", testAFilledArcIsAWedge),
            ("testARecordThatDoesNotReadIsLeftOut", testARecordThatDoesNotReadIsLeftOut),
            ("testAFingersPressDragAndReleaseArriveInPoints", testAFingersPressDragAndReleaseArriveInPoints),
        ]
    }

    static let red: UInt32 = 0xFFFF_0000
    static let blue: UInt32 = 0xFF00_00FF

    /// A red square in the top left, then a blue one moved 10 points right: at two pixels a point, the left
    /// half is red, the right half blue, and a later instruction paints over an earlier one.
    func testTheInstructionsDrawInPointsAndInOrder() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Canvas {
                    Draw.fillColor(.red)
                    Draw.fillRectangle(x: 0, y: 0, width: 15, height: 10)
                    Draw.translate(dx: 10, dy: 0)
                    Draw.fillColor(.blue)
                    Draw.fillRectangle(x: 0, y: 0, width: 10, height: 10)
                }
                .width(20).height(10).horizontalAlignment(.start)
            }
            host.layOut()
            let canvas = try XCTUnwrap(host.views(AndroidCanvasView.self).first)

            XCTAssertEqual(canvas.pixels(at: [(5, 5), (25, 5), (35, 5)]), [Self.red, Self.blue, Self.blue])
        }
    }

    /// A filled quarter from three o'clock to six, clockwise, is a wedge from the middle: the quarter below
    /// and right of the middle is filled, the one above is not.
    func testAFilledArcIsAWedge() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Canvas {
                    Draw.fillColor(.red)
                    Draw.fillArc(x: 0, y: 0, width: 20, height: 20, startAngle: 0, endAngle: 90, clockwise: true)
                }
                .width(20).height(20).horizontalAlignment(.start)
            }
            host.layOut()
            let canvas = try XCTUnwrap(host.views(AndroidCanvasView.self).first)

            XCTAssertEqual(canvas.pixels(at: [(26, 26), (26, 14)]), [Self.red, 0])
        }
    }

    /// A record that does not read whole - a rectangle with three numbers - is left out, and the rest drawn.
    func testARecordThatDoesNotReadIsLeftOut() {
        onMainActor {
            let broken = DrawCommand(propValue: .values([.enumeration(12), .number(0), .number(0), .number(5)]))!
            let (ints, numbers, _) = AndroidCanvasView.encoded([
                broken, Draw.fillColor(.red), Draw.fillRectangle(x: 0, y: 0, width: 5, height: 5),
            ])

            XCTAssertEqual(ints, [0, Int32(bitPattern: Self.red), 12])
            XCTAssertEqual(numbers, [0, 0, 5, 5])
        }
    }

    func testAFingersPressDragAndReleaseArriveInPoints() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                Canvas {}
                    .onPressed { heard.values.append("pressed \(Int($0.x)),\(Int($0.y))") }
                    .onDragged { heard.values.append("dragged \(Int($0.x)),\(Int($0.y))") }
                    .onReleased { heard.values.append("released \(Int($0.x)),\(Int($0.y))") }
                    .width(50).height(50).horizontalAlignment(.start)
            }
            host.layOut()
            let canvas = try XCTUnwrap(host.views(AndroidCanvasView.self).first)

            canvas.touch(0, x: 20, y: 40)
            canvas.touch(2, x: 30, y: 40)
            canvas.touch(1, x: 30, y: 40)

            XCTAssertEqual(heard.values, ["pressed 10,20", "dragged 15,20", "released 15,20"])
        }
    }
}
