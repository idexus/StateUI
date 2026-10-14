// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUISwitchViewTests: XCTestCase {
    /// A switch is its track and nothing else: it shows no words of WinUI's own beside it - on or off - and takes no
    /// room for them; the words beside a switch are a view of their own.
    func testASwitchShowsNoWordsOfItsOwn() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack { Switch(State(wrappedValue: true).projectedValue) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let toggle = try XCTUnwrap(host.views(WinUISwitchView.self).first)
            host.settle { toggle.frame.width > 0 }

            XCTAssertLessThanOrEqual(toggle.frame.width, 64, "no wider than its track")
            XCTAssertGreaterThan(toggle.frame.width, 0)
        }
    }
}
