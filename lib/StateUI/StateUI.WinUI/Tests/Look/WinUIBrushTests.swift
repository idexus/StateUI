// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

private let red: UInt32 = 0xFFFF_0000
private let blue: UInt32 = 0xFF00_00FF

/// Red out to 0.6 of the reach from the middle, blue past it: the edge between says how far the gradient reaches.
private let circle = Brush.radialGradient([
    GradientStop(Color(red: 255, green: 0, blue: 0), 0), GradientStop(Color(red: 255, green: 0, blue: 0), 0.6),
    GradientStop(Color(red: 0, green: 0, blue: 255), 0.6), GradientStop(Color(red: 0, green: 0, blue: 255), 1),
])

final class WinUIBrushTests: XCTestCase {
    /// A radial gradient is a circle whatever it paints: on a box 200 by 100 it reaches 100 down as across, so 40
    /// above the middle is red - an ellipse would reach 50 down and paint it blue.
    func testARadialGradientIsACircleOnAWideBox() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    ZStack {}.background(circle).width(200).height(100)
                    Rectangle().fill(circle).width(200).height(100)
                    Label("").background(circle).width(200).height(100)
                    Button("").background(circle).width(200).height(100)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let painted: [WinUIView] = [
                try XCTUnwrap(host.views(WinUIZStackView.self).first), try XCTUnwrap(host.views(WinUIPathView.self).first),
                try XCTUnwrap(host.views(WinUILabelView.self).first), try XCTUnwrap(host.views(WinUIButtonView.self).first),
            ]
            for view in painted {
                XCTAssertEqual(view.pixels(at: [(100, 10), (30, 50)]), [red, blue], "\(type(of: view))")
            }
        }
    }

    /// A box that changes its size is painted again for the new one: turned 100 by 200, 40 left of the middle is
    /// red.
    func testARadialGradientIsPaintedAgainAtANewSize() throws {
        try onUIThread {
            let tall = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                VStack {
                    ZStack {}.background(circle).width(tall.wrappedValue ? 100 : 200).height(tall.wrappedValue ? 200 : 100)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let box = try XCTUnwrap(host.views(WinUIZStackView.self).first)

            tall.wrappedValue = true
            host.settle { box.frame.height == 200 }
            host.layOut()
            XCTAssertEqual(box.pixels(at: [(10, 100), (50, 170)]), [red, blue])
        }
    }
}
