// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A stepper's buttons stand as its range lets the value move.
@MainActor
final class WebStepperViewTests: XCTestCase {
    /// At an end of its range, the button stepping past it stands disabled, the other enabled; and a stepper the
    /// tree disables disables both.
    func testAButtonAtTheRangesEndStandsDisabled() {
        let stepper = WebStepperView()
        defer { stepper.release() }
        let buttons = WebPage.children(of: stepper.node).filter { WebPage.attribute(of: $0, "type") == "button" }
        let disabled = { buttons.map { WebPage.attribute(of: $0, "disabled") != nil } }

        stepper.apply(value: 10, minimum: 0, maximum: 10, step: 1)
        XCTAssertEqual(disabled(), [false, true], "up stands disabled at the upper end")

        stepper.apply(value: 0, minimum: 0, maximum: 10, step: 1)
        XCTAssertEqual(disabled(), [true, false], "down at the lower")

        stepper.setEnabled(false)
        XCTAssertEqual(disabled(), [true, true])
    }

    /// Its buttons say the library's words to a screen reader, in the system's language.
    func testItsButtonsSayTheLibrarysWords() throws {
        let polish = try XCTUnwrap(HostLocaleInfo(words: ["pl", "PL", "pl-PL", "Europe/Warsaw", "1", "1", "1", "0"]))
        let english = try XCTUnwrap(HostLocaleInfo(words: ["en", "GB", "en-GB", "Europe/London", "1", "1", "1", "0"]))
        defer { CoreLink().setLocaleInfo(english) }
        CoreLink().setLocaleInfo(polish)

        let stepper = WebStepperView()
        defer { stepper.release() }
        let buttons = WebPage.children(of: stepper.node).filter { WebPage.attribute(of: $0, "type") == "button" }

        XCTAssertEqual(buttons.map { WebPage.attribute(of: $0, "aria-label") }, ["Zmniejsz", "Zwiększ"])
    }
}
