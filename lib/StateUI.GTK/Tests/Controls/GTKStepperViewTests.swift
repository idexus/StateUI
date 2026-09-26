// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKStepperViewTests: XCTestCase {
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

}

private extension GTKStepperView {
    /// The number as the box shows it.
    var text: String { String(cString: gtk_editable_get_text(widget.opaque)) }

    /// A step up, as the user's up button takes it.
    func stepUp() {
        gtk_spin_button_spin(widget.opaque, GTK_SPIN_STEP_FORWARD, 0)
    }
}
