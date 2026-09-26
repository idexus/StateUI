// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import StateUIHostConformance
import XCTest

final class WinUIButtonViewTests: XCTestCase {
    /// A button styled by the application wears its fill, its words' colour and its rounded corners; the corner
    /// outside the rounding shows nothing of it.
    func testAButtonWearsItsFillWordsAndCorners() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Button("Go")
                        .background(Color("#512BD4"))
                        .textColor(Color("#FFFFFF"))
                        .shape(.roundedRectangle(10))
                        .padding(16, 11)
                        .width(120)
                        .height(40)
                        .horizontalAlignment(.start)
                }
            }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)

            XCTAssertEqual(button.pixels(at: [(60, 3), (0.5, 0.5)]), [0xFF51_2BD4, 0], "the fill, a corner cut")
        }
    }

    /// A button nothing styles is WinUI's own: the platform's fill, not the application's.
    func testAButtonNothingStylesIsWinUIsOwn() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Button("Plain").width(120).height(40).horizontalAlignment(.start) } }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)

            XCTAssertNotEqual(button.pixels(at: [(60, 3)]), [0xFF51_2BD4])
            XCTAssertNotEqual(button.pixels(at: [(60, 3)]), [0], "WinUI fills its own button")
        }
    }
}
