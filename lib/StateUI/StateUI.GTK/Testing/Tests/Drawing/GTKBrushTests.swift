// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

private let red: UInt32 = 0xFFFF_0000
private let blue: UInt32 = 0xFF00_00FF

/// Red out to 0.6 of the reach from the middle, blue past it: the edge between says how far the gradient reaches.
private let circle = Brush.radialGradient([
    GradientStop(Color(red: 255, green: 0, blue: 0), 0), GradientStop(Color(red: 255, green: 0, blue: 0), 0.6),
    GradientStop(Color(red: 0, green: 0, blue: 255), 0.6), GradientStop(Color(red: 0, green: 0, blue: 255), 1),
])

@MainActor
final class GTKBrushTests: XCTestCase {
    /// A radial gradient is a circle whatever it paints: on a box 200 by 100 it reaches 100 down as across, so 40
    /// above the middle is red - an ellipse would reach 50 down and paint it blue; turned 100 by 200, 40 left of the
    /// middle is red.
    func testARadialGradientIsACircleOnABoxNotSquare() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ZStack {}.background(circle).width(200).height(100)
                    Rectangle().fill(circle).width(200).height(100)
                    ZStack {}.background(circle).width(100).height(200)
                    Rectangle().fill(circle).width(100).height(200)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let boxes = host.views(GTKZStackView.self)
            let shapes = host.views(GTKShapeView.self)
            XCTAssertEqual([boxes.count, shapes.count], [2, 2])
            host.settle { (boxes + shapes).allSatisfy { $0.pixels(at: [(50, 50)]) != [0] } }

            for view in [boxes[0], shapes[0]] {
                XCTAssertEqual(view.pixels(at: [(100, 10), (30, 50)]), [red, blue], "wide \(type(of: view))")
            }
            for view in [boxes[1], shapes[1]] {
                XCTAssertEqual(view.pixels(at: [(10, 100), (50, 170)]), [red, blue], "tall \(type(of: view))")
            }
        }
    }
}
