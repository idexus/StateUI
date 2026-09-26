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
}
