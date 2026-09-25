// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUIStepperViewTests: XCTestCase {
    /// The user's step reaches the state and the handler once; the program's value is kept inside the range and
    /// heard by nobody.
    func testAUsersStepIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let count = State(wrappedValue: 2.0)
            let heard = Received<Double>()
            let host = WinUIRenderer.running {
                VStack {
                    Stepper(count.projectedValue).minimum(0).maximum(10).step(1)
                        .onValueChanged { heard.values.append($0) }
                    Button("Too many").onClicked { count.wrappedValue = 20 }
                }
            }
            let stepper = try XCTUnwrap(host.views(WinUIStepperView.self).first)
            XCTAssertEqual(stepper.value, 2)

            stepper.move(to: 3)
            host.settle { count.wrappedValue == 3 }
            XCTAssertEqual(count.wrappedValue, 3)
            XCTAssertEqual(heard.values, [3])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { stepper.value == 10 }
            XCTAssertEqual(stepper.value, 10, "kept inside its range")
            XCTAssertEqual(heard.values, [3], "and nobody heard the program")
        }
    }

    /// A stepper writes its number with as many decimals as its step and its range take.
    func testANumberTakesTheDecimalsItsStepTakes() {
        XCTAssertEqual(WinUIStepperView.decimals(of: [1, 0, 10, 3]), 0)
        XCTAssertEqual(WinUIStepperView.decimals(of: [0.25, 0, 1, 0.5]), 2)
        XCTAssertEqual(WinUIStepperView.decimals(of: [0.1, 0, 1, .nan]), 1)
    }
}
