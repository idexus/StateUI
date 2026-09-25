// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A picker whose choice and list a button of the program's changes too, saying what it heard.
private struct PickerPage: ContentView {
    let heard: Received<String>
    @State private var size = 1
    @State private var showing = false

    var content: any View {
        let heard = heard
        return VStack {
            Picker(["S", "M", "L"])
                .selectedIndex($size)
                .title("Size")
                .isOpen(showing)
                .onSelectedIndexChanged { heard.values.append("chose \($0)") }
                .onOpened { heard.values.append("opened") }
                .onClosed {
                    heard.values.append("closed")
                    showing = false
                }
            Button("Open").onClicked { showing = true }
            Button("Small").onClicked { size = 0 }
        }
    }
}

final class WinUIPickerViewTests: XCTestCase {
    /// The user's choice is heard once and reaches the state; the program's is shown and heard by nobody.
    func testAUsersChoiceIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { PickerPage(heard: heard) }
            let picker = try XCTUnwrap(host.views(WinUIPickerView.self).first)
            XCTAssertEqual(picker.chosen, 1)

            stateui_winui_picker_choose_as_user(picker.handle, 2)
            host.settle { heard.values == ["chose 2"] }
            XCTAssertEqual(heard.values, ["chose 2"])

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { picker.chosen == 0 }
            XCTAssertEqual(picker.chosen, 0, "the program's choice shown")
            XCTAssertEqual(heard.values, ["chose 2"], "and heard by nobody")
        }
    }

    /// The list the user opens and closes is heard; the program's opening is not, and the user closing the list
    /// the program opened is.
    func testTheUsersOpeningAndClosingAreHeardAndTheProgramsOpeningIsNot() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { PickerPage(heard: heard) }
            let picker = try XCTUnwrap(host.views(WinUIPickerView.self).first)

            stateui_winui_picker_open_as_user(picker.handle, true)
            host.settle { heard.values == ["opened"] }
            stateui_winui_picker_open_as_user(picker.handle, false)
            host.settle { heard.values == ["opened", "closed"] }
            XCTAssertEqual(heard.values, ["opened", "closed"])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { picker.isOpen }
            XCTAssertTrue(picker.isOpen, "the program opened the list")
            XCTAssertEqual(heard.values, ["opened", "closed"], "and nobody heard it")

            stateui_winui_picker_open_as_user(picker.handle, false)
            host.settle { heard.values.count == 3 }
            XCTAssertEqual(heard.values, ["opened", "closed", "closed"], "the user closed what the program opened")
        }
    }
}
