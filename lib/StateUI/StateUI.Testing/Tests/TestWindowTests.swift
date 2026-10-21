// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUITesting
import XCTest

/// A test's window shows a page with no toolkit, finds its views as automation does, and acts on them as the user
/// does - each act's work done before the test reads what it changed.
@MainActor
final class TestWindowTests: XCTestCase {
    func testAClickIsCounted() async throws {
        let window = try await TestWindow(motion: .none) { CounterPage() }
        let button = try window.element("counter.add")
        XCTAssertEqual(button.value(TextualElementContract.text), "Clicked 0 times")

        try await button.perform(.activate)
        try await button.perform(.activate)

        XCTAssertEqual(button.value(TextualElementContract.text), "Clicked 2 times")
    }

    /// Words typed reach the state the field is bound to, and a switch turned reaches its own.
    func testWordsTypedAndASwitchTurnedReachTheirStates() async throws {
        let window = try await TestWindow(motion: .none) { FormPage() }
        let field = try window.element("form.name")
        let lamp = try window.element("form.lamp")

        try await field.perform(.type("Ada"))
        try await lamp.perform(.toggle)

        XCTAssertEqual(try window.element("form.greeting").value(TextualElementContract.text), "Hello, Ada - lit")
        XCTAssertEqual(lamp.value(SwitchContract.isOn), true)
    }

    /// A view is found by the aim put on it, as the application aims at it.
    func testAViewIsFoundByItsAim() async throws {
        let page = AimedPage()
        let window = try await TestWindow(motion: .none) { page }
        let field = try window.element(page.name)

        try await field.perform(.type("Grace"))

        XCTAssertEqual(field.value(TextualElementContract.text), "Grace")
    }

    /// The walk every host's suite takes a window through holds with no toolkit too.
    func testTheWalkHoldsWithNoToolkit() {
        XCTAssertEqual(TestWindowWalk.failures(on: CoreDriver()), [])
    }

    /// A view no view is, or one two views are, is a failure naming it - not a guess.
    func testAViewNotThereOrTwiceThereFails() async throws {
        let window = try await TestWindow(motion: .none) { FormPage() }

        XCTAssertThrowsError(try window.element("form.nothing")) { error in
            XCTAssertEqual("\(error)", "no view is the view \"form.nothing\"")
        }
        XCTAssertThrowsError(try window.element("form.twice")) { error in
            XCTAssertEqual("\(error)", "2 views are the view \"form.twice\"")
        }
    }
}
