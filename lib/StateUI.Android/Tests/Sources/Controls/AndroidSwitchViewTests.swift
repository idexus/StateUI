// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidSwitchViewTests: XCTestCase {
    static var allTests: [(String, (AndroidSwitchViewTests) -> () throws -> Void)] {
        [
            ("testASwitchShowsWhatTheTreeSays", testASwitchShowsWhatTheTreeSays),
            ("testAUsersTurnReachesTheStateAndTheHandlerOnce", testAUsersTurnReachesTheStateAndTheHandlerOnce),
        ]
    }

    /// The tree turns the switch, and the program's turn is not heard as the user's.
    func testASwitchShowsWhatTheTreeSays() throws {
        try onMainActor {
            let on = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = AndroidRenderer.running {
                VStack {
                    Switch(on.projectedValue).onToggled { heard.values.append($0) }
                    Button("On").onClicked { on.wrappedValue = true }
                }
            }
            let toggle = try XCTUnwrap(host.views(AndroidSwitchView.self).first)
            XCTAssertFalse(toggle.isOn)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()

            XCTAssertTrue(toggle.isOn, "the state the button wrote reached the switch")
            XCTAssertEqual(heard.values, [], "and nobody heard it as the user's")
        }
    }

    func testAUsersTurnReachesTheStateAndTheHandlerOnce() throws {
        try onMainActor {
            let on = State(wrappedValue: false)
            let heard = Received<Bool>()
            let host = AndroidRenderer.running {
                VStack {
                    Label(on.wrappedValue ? "on" : "off")
                    Switch(on.projectedValue).onToggled { heard.values.append($0) }
                }
            }
            let toggle = try XCTUnwrap(host.views(AndroidSwitchView.self).first)

            toggle.click()

            XCTAssertTrue(on.wrappedValue)
            XCTAssertEqual(heard.values, [true])
            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["on"])
            XCTAssertTrue(toggle.isOn)
        }
    }
}
