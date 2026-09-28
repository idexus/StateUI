// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import XCTest

final class WinUICheckBoxViewTests: XCTestCase {
    /// A check box is the box and nothing else: it takes no caption's room.
    func testACheckBoxTakesItsBoxsRoomAlone() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack { CheckBox(State(wrappedValue: true).projectedValue) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)

            XCTAssertLessThanOrEqual(box.frame.width, 32, "no wider than its box")
            XCTAssertGreaterThan(box.frame.width, 0)
        }
    }
}
