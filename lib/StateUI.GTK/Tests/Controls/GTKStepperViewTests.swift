// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

final class GTKStepperViewTests: XCTestCase {
    /// The user's step reaches the state and the handler once; the program's value is kept inside the range and
    /// heard by nobody.
    func testAUsersStepIsHeardAndTheProgramsIsNot() throws {
        try onUIThread {
            let count = State(wrappedValue: 2.0)
            let heard = Received<Double>()
            let host = GTKRenderer.running {
                VStack {
                    Stepper(count.projectedValue).minimum(0).maximum(10).step(1)
                        .onValueChanged { heard.values.append($0) }
                    Button("Too many").onClicked { count.wrappedValue = 20 }
                }
            }
            let stepper = try XCTUnwrap(host.views(GTKStepperView.self).first)
            XCTAssertEqual(stepper.value, 2)

            stepper.stepUp()
            host.settle { count.wrappedValue == 3 }
            XCTAssertEqual(count.wrappedValue, 3)
            XCTAssertEqual(heard.values, [3])

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { stepper.value == 10 }
            XCTAssertEqual(stepper.value, 10, "kept inside its range")
            XCTAssertEqual(heard.values, [3], "and nobody heard the program")
        }
    }

    /// A stepper writes its number with as many decimals as its step and its range take, and steps by its step.
    func testAStepperWritesTheDecimalsItsStepTakes() throws {
        try onUIThread {
            let level = State(wrappedValue: 0.5)
            let host = GTKRenderer.running {
                VStack { Stepper(level.projectedValue).minimum(0).maximum(1).step(0.25) }
            }
            let stepper = try XCTUnwrap(host.views(GTKStepperView.self).first)
            XCTAssertEqual(stepper.text, "0.50")

            stepper.stepUp()
            host.settle { level.wrappedValue == 0.75 }
            XCTAssertEqual(stepper.text, "0.75")
        }
    }

    /// Words that say no number, empty ones too, leave the number where it was, heard by nobody; a number typed past
    /// an end stands at that end.
    func testTypedWordsThatSayNoNumberLeaveTheNumber() throws {
        try onUIThread {
            let count = State(wrappedValue: 4.0)
            let heard = Received<Double>()
            let host = GTKRenderer.running {
                VStack {
                    Stepper(count.projectedValue).minimum(2).maximum(10).step(1)
                        .onValueChanged { heard.values.append($0) }
                }
            }
            let stepper = try XCTUnwrap(host.views(GTKStepperView.self).first)

            for words in ["", "  ", "abc", "5x"] {
                stepper.type(words)
                host.pump.turn()
                XCTAssertEqual(count.wrappedValue, 4, "'\(words)'")
                XCTAssertEqual(stepper.text, "4", "the box shows the number again")
            }
            XCTAssertEqual(heard.values, [])

            stepper.type("20")
            host.settle { count.wrappedValue == 10 }
            XCTAssertEqual(count.wrappedValue, 10)
            XCTAssertEqual(heard.values, [10])
        }
    }
}

private extension GTKStepperView {
    /// The number as the box shows it.
    var text: String { String(cString: gtk_editable_get_text(widget.opaque)) }

    /// The user's words in the box, taken as the box takes them when Enter is pressed or it loses the focus.
    func type(_ words: String) {
        gtk_editable_set_text(widget.opaque, words)
        gtk_spin_button_update(widget.opaque)
    }

    /// A step up, as the user's up button takes it.
    func stepUp() {
        gtk_spin_button_spin(widget.opaque, GTK_SPIN_STEP_FORWARD, 0)
    }
}
