// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// Two fields saying whether each holds the keyboard.
private struct FocusPage: ContentView {
    let heard: Received<String>

    var content: any View {
        let heard = heard
        return VStack {
            TextField("First").onEvent(VisualElementContract.isFocusedChanged) { heard.values.append("first \($0)") }
            TextField("Second").onEvent(VisualElementContract.isFocusedChanged) { heard.values.append("second \($0)") }
        }
    }
}

final class WinUIFocusTests: XCTestCase {
    /// The keyboard coming into a view is heard there, and its going on to another is heard as it leaves.
    func testTheKeyboardComingAndGoingIsHeard() {
        onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { FocusPage(heard: heard) }
            let fields = host.views(WinUITextFieldView.self)
            XCTAssertEqual(fields.count, 2)

            XCTAssertTrue(stateui_winui_focus(fields[0].handle, true))
            host.settle { heard.values == ["first true"] }
            XCTAssertTrue(stateui_winui_focus(fields[1].handle, true))
            host.settle { heard.values.count == 3 }
            XCTAssertEqual(heard.values, ["first true", "first false", "second true"])
        }
    }
}
