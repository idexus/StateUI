// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUICheckBoxViewTests: XCTestCase {
    /// The user's tick reaches the state and the handler once; the program's tick is heard by nobody.
    func testAUsersTickIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let ticked = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = WinUIRenderer.running {
                VStack {
                    CheckBox(ticked.projectedValue).onToggled { heard.values.append($0) }
                    Button("Untick").onClicked { ticked.wrappedValue = false }
                }
            }
            let box = try XCTUnwrap(host.views(WinUICheckBoxView.self).first)

            box.toggle()
            host.settle { ticked.wrappedValue }
            XCTAssertTrue(ticked.wrappedValue)
            XCTAssertEqual(heard.values, [true])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { !box.isOn }
            XCTAssertFalse(box.isOn, "the state the button wrote reached the box")
            XCTAssertEqual(heard.values, [true], "and nobody heard it as the user's")
        }
    }

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
