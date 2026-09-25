// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUIRadioButtonViewTests: XCTestCase {
    /// A radio button is drawn over the background it is given, and the one checked wears its Checked wash, which
    /// moves with the user's choice.
    func testTheCheckedWashFollowsTheUsersChoice() {
        onUIThread {
            let ready = State(wrappedValue: true)
            let busy = State(wrappedValue: false)
            let red: [UInt32] = [0xFFFF_0000]
            let host = WinUIRenderer.running {
                VStack {
                    RadioButton("Ready").isOn(ready.projectedValue)
                        .visualState(.checked) { $0.background(Color("#FF0000")) }
                        .width(200).height(40)
                    RadioButton("Busy").isOn(busy.projectedValue)
                        .visualState(.checked) { $0.background(Color("#FF0000")) }
                        .width(200).height(40)
                }
                .horizontalAlignment(.start)
            }
            let radios = host.views(WinUIRadioButtonView.self)
            XCTAssertEqual(radios.count, 2)
            XCTAssertEqual(radios[0].pixels(at: [(190, 20)]), red, "the checked one")
            XCTAssertNotEqual(radios[1].pixels(at: [(190, 20)]), red)

            radios[1].toggle()
            host.settle { radios[1].pixels(at: [(190, 20)]) == red }
            XCTAssertEqual(radios[1].pixels(at: [(190, 20)]), red, "the one the user chose")
            XCTAssertNotEqual(radios[0].pixels(at: [(190, 20)]), red, "and not the one before")
        }
    }

    /// The user checks one radio button of a named set: the one checked before reports it is off, then the new one
    /// that it is on, and the tree's choice follows.
    func testAUsersChoiceTakesTheGroupsOtherCheckAway() {
        onUIThread {
            let choice = State(wrappedValue: "Small")
            let heard = Received<String>()
            let host = WinUIRenderer.running {
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
            let radios = host.views(WinUIRadioButtonView.self)
            XCTAssertEqual(radios.map(\.text), ["Small", "Large"])
            XCTAssertEqual(radios.map(\.isOn), [true, false])

            radios[1].toggle()
            host.settle { choice.wrappedValue == "Large" }

            XCTAssertEqual(heard.values, ["Small false", "Large true"])
            XCTAssertEqual(choice.wrappedValue, "Large")
            XCTAssertEqual(radios.map(\.isOn), [false, true])
        }
    }

    /// Buttons that name no set are a set with their siblings alone, and each change is heard once: WinUI takes no
    /// check away itself, the host does.
    func testButtonsNamingNoSetAreOneWithTheirSiblings() {
        onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running {
                VStack {
                    ForEach(["A", "B"]) { name in
                        RadioButton(name).isOn(name == "A").onToggled { heard.values.append("\(name) \($0)") }.id(name)
                    }
                    HStack {
                        RadioButton("C").isOn(true).onToggled { heard.values.append("C \($0)") }
                    }
                }
            }
            let radios = host.views(WinUIRadioButtonView.self)

            radios[1].toggle()
            host.settle { heard.values.count == 2 }

            XCTAssertEqual(heard.values, ["A false", "B true"])
            XCTAssertEqual(radios.map(\.isOn), [false, true, true], "C, beside no other, keeps its check")
        }
    }
}
