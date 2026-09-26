// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The focus is the platform's, and a view that watches it hears every move -
/// an act's, the user's, the window's own.
final class AppKitFocusTests: XCTestCase {
    /// Pumps until `done` holds: a focus move is reported once it has settled,
    /// and the binding it writes renders on the next pump.
    @MainActor
    private func settle(_ renderer: AppKitRenderer, until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.pump()
        }
    }

    /// A field bound with `isFocused` reports the focus whatever moved it: an
    /// act, and the window's first responder changed by hand.
    @MainActor
    func testAFieldReportsTheFocusWhateverMovesIt() throws {
        let renderer = AppKitRenderer.running { Watching() }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)
        let field = try XCTUnwrap(renderer.nativeViews(NSTextField.self).first { $0.isEditable })
        let window = try XCTUnwrap(field.window)
        let shown = { renderer.nativeViews(AppKitLabelView.self).last?.textForTesting.string }
        XCTAssertEqual(shown(), "idle")

        buttons[0].clickForTesting()
        settle(renderer) { shown() == "editing" }
        XCTAssertEqual(shown(), "editing", "an act's focus is reported")

        buttons[1].clickForTesting()
        settle(renderer) { shown() == "idle" }
        XCTAssertEqual(shown(), "idle")

        window.makeFirstResponder(field)
        settle(renderer) { shown() == "editing" }
        XCTAssertEqual(shown(), "editing", "so is the window's own")

        window.makeFirstResponder(nil)
        settle(renderer) { shown() == "idle" }
        XCTAssertEqual(shown(), "idle")
    }
}

/// A field that says whether it has the focus, and two buttons that move it.
private struct Watching: ContentView {
    @State private var name = ""
    @State private var editing = false
    @Aim(TextField.self) private var field

    var content: any View {
        VStack {
            TextField($name).aim(field).isFocused($editing)
            Button("Focus").onClicked { try await field.focus() }
            Button("Unfocus").onClicked { try await field.unfocus() }
            Label(editing ? "editing" : "idle")
        }
    }
}
#endif
