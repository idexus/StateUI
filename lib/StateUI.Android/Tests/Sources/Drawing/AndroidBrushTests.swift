// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidBrushTests: XCTestCase {
    static var allTests: [(String, (AndroidBrushTests) -> () throws -> Void)] {
        [
            ("testARadialGradientIsACircleOnABoxNotSquare", testARadialGradientIsACircleOnABoxNotSquare),
        ]
    }

    static let red: UInt32 = 0xFFFF_0000
    static let blue: UInt32 = 0xFF00_00FF

    /// Red out to 0.6 of the reach from the middle, blue past it: the edge between says how far the gradient reaches.
    static let circle = Brush.radialGradient([
        GradientStop(Color(red: 255, green: 0, blue: 0), 0), GradientStop(Color(red: 255, green: 0, blue: 0), 0.6),
        GradientStop(Color(red: 0, green: 0, blue: 255), 0.6), GradientStop(Color(red: 0, green: 0, blue: 255), 1),
    ])

    /// A radial gradient is a circle whatever it paints: on a box 200 by 100 it reaches 100 down as across, so 40
    /// above the middle is red - an ellipse would reach 50 down and paint it blue; turned 100 by 200, 40 left of the
    /// middle is red. At two pixels a point; the wide box is a view's background, the tall one a layout's own box.
    func testARadialGradientIsACircleOnABoxNotSquare() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    ZStack {}.background(Self.circle).width(200).height(100)
                    Rectangle().fill(Self.circle).width(200).height(100)
                    ZStack {}.background(Self.circle).shape(.rectangle).width(100).height(200)
                    Rectangle().fill(Self.circle).width(100).height(200)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()
            let boxes = host.views(AndroidZStackView.self)
            let shapes = host.views(AndroidShapeView.self)
            XCTAssertEqual([boxes.count, shapes.count], [2, 2])

            for view in [boxes[0], shapes[0]] as [AndroidView] {
                XCTAssertEqual(view.pixels(at: [(200, 20), (60, 100)]), [Self.red, Self.blue], "wide \(type(of: view))")
            }
            for view in [boxes[1], shapes[1]] as [AndroidView] {
                XCTAssertEqual(view.pixels(at: [(20, 200), (100, 340)]), [Self.red, Self.blue], "tall \(type(of: view))")
            }
        }
    }
}
