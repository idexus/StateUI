// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidShapeViewTests: XCTestCase {
    static var allTests: [(String, (AndroidShapeViewTests) -> () throws -> Void)] {
        [
            ("testARectangleAndAnEllipseFillTheirRoom", testARectangleAndAnEllipseFillTheirRoom),
            ("testDrawnGeometryFitsItsRoom", testDrawnGeometryFitsItsRoom),
            ("testAPathsArcBendsToItsTop", testAPathsArcBendsToItsTop),
            ("testAShapeAsksForNoRoom", testAShapeAsksForNoRoom),
        ]
    }

    static let red: UInt32 = 0xFFFF_0000

    /// A rectangle reaches its corners; an ellipse leaves them and fills its middle.
    func testARectangleAndAnEllipseFillTheirRoom() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Rectangle().fill(.red).width(20).height(20).horizontalAlignment(.start)
                    Ellipse().fill(.red).width(20).height(20).horizontalAlignment(.start)
                }
            }
            host.layOut()
            let shapes = host.views(AndroidShapeView.self)

            XCTAssertEqual(shapes[0].pixels(at: [(1, 1), (20, 20)]), [Self.red, Self.red])
            XCTAssertEqual(shapes[1].pixels(at: [(1, 1), (20, 20)]), [0, Self.red])
        }
    }

    /// A triangle authored 10 wide and 10 tall, fitted into 40 by 20 points: 20 by 20 in the middle, so the
    /// room's left edge is empty, the triangle's foot is filled, and beside its apex is empty.
    func testDrawnGeometryFitsItsRoom() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Polygon([Point(0, 10), Point(5, 0), Point(10, 10)]).fill(.red)
                    .width(40).height(20).horizontalAlignment(.start)
            }
            host.layOut()
            let triangle = try XCTUnwrap(host.views(AndroidShapeView.self).first)

            XCTAssertEqual(triangle.pixels(at: [(10, 38), (40, 36), (30, 2)]), [0, Self.red, 0])
        }
    }

    /// A half circle's arc, authored 20 wide, reaches its top in the middle - drawn as the shared curves.
    func testAPathsArcBendsToItsTop() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Path("M 0 10 A 10 10 0 0 1 20 10 Z").fill(.red).aspect(.center)
                    .width(20).height(20).horizontalAlignment(.start)
            }
            host.layOut()
            let arc = try XCTUnwrap(host.views(AndroidShapeView.self).first)

            // Centred, the half circle stands from 10 to 30 pixels down: its top middle is filled, the
            // corner beside it is not.
            XCTAssertEqual(arc.pixels(at: [(20, 12), (2, 12)]), [Self.red, 0])
        }
    }

    func testAShapeAsksForNoRoom() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack { Rectangle().fill(.red).horizontalAlignment(.start) }
            }
            host.layOut()
            let rectangle = try XCTUnwrap(host.views(AndroidShapeView.self).first)

            XCTAssertEqual(rectangle.frame.height, 0)
        }
    }
}
