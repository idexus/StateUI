// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
import StateUITesting
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

/// A button counting its clicks.
private struct CounterPage: View {
    @State private var clicks = 0

    var body: some View {
        Button("Clicked \(clicks) time\(clicks == 1 ? "" : "s")")
            .accessibilityIdentifier("counter.add")
            .onClicked { clicks += 1 }
    }
}

/// A field, a switch, and the greeting both make.
private struct FormPage: View {
    @State private var name = ""
    @State private var lit = false

    var body: some View {
        VStack {
            TextField($name).accessibilityIdentifier("form.name")
            Switch($lit).accessibilityIdentifier("form.lamp")
            Text("Hello, \(name) - \(lit ? "lit" : "dark")").accessibilityIdentifier("form.greeting")
            Text("One").accessibilityIdentifier("form.twice")
            Text("Two").accessibilityIdentifier("form.twice")
        }
    }
}

/// A field the page aims at.
private struct AimedPage: View {
    @Aim(TextField.self) var name
    @State private var words = ""

    var body: some View {
        TextField($words).aim(name)
    }
}
