// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUISliderViewTests: XCTestCase {
    /// On a desktop the keyboard moves a slider too: an arrow key a hundredth of the range, Page Up a tenth, while a
    /// drag lands on a ten-thousandth.
    func testTheKeyboardMovesASliderInSteps() throws {
        try onUIThread {
            let level = State(wrappedValue: 2.0)
            let host = WinUIRenderer.running { VStack { Slider(level.projectedValue).minimum(0).maximum(10) } }
            let steps = try XCTUnwrap(host.views(WinUISliderView.self).first).steps

            XCTAssertEqual(steps.key, 0.1, accuracy: 1e-9)
            XCTAssertEqual(steps.page, 1, accuracy: 1e-9)
            XCTAssertEqual(steps.drag, 0.001, accuracy: 1e-9)
        }
    }
}
