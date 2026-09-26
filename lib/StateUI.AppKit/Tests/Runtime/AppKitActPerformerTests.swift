// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The acts the application calls on the host are performed and answered: a
/// caller never waits on an act nobody performs.
final class AppKitActPerformerTests: XCTestCase {
    /// Pumps until `done` holds - an act's answer resumes its handler, and the
    /// handler's write renders on the next pump.
    @MainActor
    private func settle(_ renderer: AppKitRenderer, until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.pump()
        }
    }

    /// `focus` puts the keyboard on the aimed field and answers that it took
    /// it; `unfocus` takes it off; `hideOnScreenKeyboard` takes it off
    /// whatever holds it and answers whether anything did.
    @MainActor
    func testTheFocusActsReachTheWindowAndAnswer() throws {
        let renderer = AppKitRenderer.running { Focusing() }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)
        let field = try XCTUnwrap(renderer.nativeViews(NSTextField.self).first { $0.isEditable })
        let answer = { renderer.nativeViews(AppKitLabelView.self).last?.textForTesting.string }
        XCTAssertEqual(buttons.count, 3)

        buttons[0].clickForTesting()
        settle(renderer) { answer() == "took" }
        XCTAssertEqual(answer(), "took")
        XCTAssertNotNil(field.currentEditor(), "the field holds the keyboard")

        buttons[1].clickForTesting()
        settle(renderer) { answer() == "released" }
        XCTAssertEqual(answer(), "released")
        XCTAssertNil(field.currentEditor())

        buttons[0].clickForTesting()
        settle(renderer) { answer() == "took" }
        buttons[2].clickForTesting()
        settle(renderer) { answer() == "hid" }
        XCTAssertEqual(answer(), "hid")
        XCTAssertNil(field.currentEditor())

        buttons[2].clickForTesting()
        settle(renderer) { answer() == "nothing" }
        XCTAssertEqual(answer(), "nothing", "the keyboard was already down")
    }

    /// An act lands on the interface its handler changed: the pump renders
    /// before it acts, so a field enabled and focused in the same breath is
    /// enabled by the time the focus reaches it, and takes the keyboard.
    @MainActor
    func testAnActLandsOnTheInterfaceItsHandlerChanged() throws {
        let renderer = AppKitRenderer.running { EnablingAndFocusing() }
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        let answer = { renderer.nativeViews(AppKitLabelView.self).last?.textForTesting.string }

        button.clickForTesting()
        settle(renderer) { answer() != "-" }

        XCTAssertEqual(answer(), "took", "the focus reached the field before the render enabled it")
    }
}

/// A field aimed at by three buttons, and what the last act answered.
private struct Focusing: ContentView {
    @State private var name = ""
    @State private var answer = "-"
    @Aim(TextField.self) private var field

    var content: any View {
        VStack {
            TextField($name).aim(field)
            Button("Focus").onClicked { answer = try await field.focus() ? "took" : "refused" }
            Button("Unfocus").onClicked {
                try await field.unfocus()
                answer = "released"
            }
            Button("Hide").onClicked {
                answer = try await OnScreenKeyboard.hide() ? "hid" : "nothing"
            }
            Label(answer)
        }
    }
}

/// A disabled field, and a button that enables it and focuses it in one breath.
private struct EnablingAndFocusing: ContentView {
    @State private var name = ""
    @State private var enabled = false
    @State private var answer = "-"
    @Aim(TextField.self) private var field

    var content: any View {
        VStack {
            TextField($name).aim(field).isEnabled(enabled)
            Button("Enable and focus").onClicked {
                enabled = true
                answer = try await field.focus() ? "took" : "refused"
            }
            Label(answer)
        }
    }
}
#endif
