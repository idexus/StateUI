// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidRadioButtonViewTests: XCTestCase {
    static var allTests: [(String, (AndroidRadioButtonViewTests) -> () throws -> Void)] {
        [
            ("testAUsersChoiceTakesTheGroupsOtherCheckAway", testAUsersChoiceTakesTheGroupsOtherCheckAway),
        ]
    }

    /// The user checks one radio button of a group: the one checked before reports it is off, then the new one
    /// that it is on, and the tree's choice follows.
    func testAUsersChoiceTakesTheGroupsOtherCheckAway() {
        onMainActor {
            let choice = State(wrappedValue: "Small")
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                VStack {
                    ForEach(["Small", "Large"]) { name in
                        RadioButton(name)
                            .groupName("size")
                            .isOn(choice.wrappedValue == name)
                            .onToggled { chosen in
                                heard.values.append("\(name) \(chosen)")
                                if chosen { choice.wrappedValue = name }
                            }
                            .id(name)
                    }
                }
            }
            let radios = host.views(AndroidRadioButtonView.self)
            XCTAssertEqual(radios.map(\.text), ["Small", "Large"])
            XCTAssertEqual(radios.map(\.isOn), [true, false])

            radios[1].click()

            XCTAssertEqual(heard.values, ["Small false", "Large true"])
            XCTAssertEqual(choice.wrappedValue, "Large")
            XCTAssertEqual(radios.map(\.isOn), [false, true])
        }
    }
}
