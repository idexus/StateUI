// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

final class GTKSwitchViewTests: XCTestCase {
    /// The tree turns the switch, and the program's turn is not heard as the user's.
    func testASwitchShowsWhatTheTreeSays() throws {
        try onUIThread {
            let on = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = GTKRenderer.running {
                VStack {
                    Switch(on.projectedValue).onToggled { heard.values.append($0) }
                    Button("On").onClicked { on.wrappedValue = true }
                }
            }
            let toggle = try XCTUnwrap(host.views(GTKSwitchView.self).first)
            XCTAssertFalse(toggle.isOn)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()

            XCTAssertTrue(toggle.isOn, "the state the button wrote reached the switch")
            XCTAssertEqual(heard.values, [], "and nobody heard it as the user's")
        }
    }

    func testAUsersTurnReachesTheStateAndTheHandlerOnce() throws {
        try onUIThread {
            let on = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = GTKRenderer.running {
                VStack {
                    Label(on.wrappedValue ? "on" : "off")
                    Switch(on.projectedValue).onToggled { heard.values.append($0) }
                }
            }
            let toggle = try XCTUnwrap(host.views(GTKSwitchView.self).first)

            toggle.toggle()

            XCTAssertTrue(on.wrappedValue)
            XCTAssertEqual(heard.values, [true])
            XCTAssertEqual(host.views(GTKLabelView.self).map(\.text), ["on"])
            XCTAssertTrue(toggle.isOn)
        }
    }
}
