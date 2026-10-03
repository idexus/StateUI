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
            renderer.runtime.pump.turn()
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
        let shown = { renderer.nativeViews(AppKitTextView.self).last?.textForTesting.string }
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

    /// Tab moves the focus from a field to the next one down, and Shift-Tab back: the window's own key view loop,
    /// worked out from where its views stand - on a window's page and on a sheet alike.
    @MainActor
    func testTabMovesTheFocusToTheNextField() throws {
        for (place, renderer) in [
            ("a window's page", AppKitRenderer.running { TwoFields() }),
            ("a sheet", AppKitRenderer.running {
                ModalStack(State(wrappedValue: [1]).projectedValue) { Text("Under") } destination: { _ in TwoFields() }
            }),
        ] {
            defer { renderer.closeForTesting() }
            let shown = {
                let window = renderer.windowsForTesting.first
                let content = (window?.modals.last?.window ?? window?.window)?.contentView
                return content.map { AppKitRenderer.views(NSTextField.self, in: $0) }?.filter(\.isEditable) ?? []
            }
            settle(renderer) { shown().count == 2 }
            let fields = shown()
                .sorted { $0.convert($0.bounds, to: nil).maxY > $1.convert($1.bounds, to: nil).maxY }
            let window = try XCTUnwrap(fields.first?.window, place)
            XCTAssertEqual(fields.count, 2, place)
            window.makeFirstResponder(fields[0])

            // What the Tab key does in a field: its editor asks the window for the next key view.
            (window.firstResponder as? NSTextView)?.insertTab(nil)
            XCTAssertTrue(Self.edits(fields[1], in: window), "Tab goes to the field below, on \(place)")

            (window.firstResponder as? NSTextView)?.insertBacktab(nil)
            XCTAssertTrue(Self.edits(fields[0], in: window), "Shift-Tab comes back, on \(place)")
        }
    }

    /// Whether `field` is being edited in `window`: the window's field editor works for it.
    @MainActor
    private static func edits(_ field: NSTextField, in window: NSWindow) -> Bool {
        (window.firstResponder as? NSText)?.delegate === field
    }
}

/// Two fields one under the other, as a sign-in has them.
private struct TwoFields: View {
    @State private var code = ""
    @State private var password = ""

    var body: some View {
        VStack {
            TextField($code).placeholder("Code")
            TextField($password).placeholder("Password").isPassword(true)
        }
    }
}

/// A field that says whether it has the focus, and two buttons that move it.
private struct Watching: View {
    @State private var name = ""
    @State private var editing = false
    @Aim(TextField.self) private var field

    var body: some View {
        VStack {
            TextField($name).aim(field).isFocused($editing)
            Button("Focus").onClicked { try await field.focus() }
            Button("Unfocus").onClicked { try await field.unfocus() }
            Text(editing ? "editing" : "idle")
        }
    }
}
#endif
