// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUISwitchViewTests: XCTestCase {
    /// A switch with no words is its track and nothing else: it shows no words of WinUI's own beside it - on or off
    /// - and takes no room for them.
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

    /// A toggle says its words as WinUI's own control does - a switch's header, a check box's words beside its box -
    /// in their case and color.
    func testATogglesWordsAreItsOwn() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Switch(false).text("Wi-Fi")
                    CheckBox(true).text("agree").textCase(.uppercase).textColor(Color(hex: 0xFF0000))
                }
            }
            XCTAssertEqual(try XCTUnwrap(host.views(WinUISwitchView.self).first).text, "Wi-Fi")
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)
            XCTAssertEqual(box.text, "AGREE")
            XCTAssertEqual(WinUIStrings.read { stateui_winui_read(box.handle, "foreground", $0, $1) }, "#FFFF0000")
        }
    }
}
