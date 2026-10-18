// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitQuestionTests: XCTestCase {
    /// A prompt's field types for its purpose: a plain one predicts nothing, and the editor it types through
    /// neither checks nor corrects its spelling.
    func testAPromptsFieldTypesForItsPurpose() throws {
        let question = try XCTUnwrap(HostQuestion(HostActCall(
            act: .prompt, arguments: [.string("Code"), .nothing, .nothing, .nothing, .nothing, .nothing,
                                      InputPurpose.plain.propValue], completion: 1)))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered,
            defer: true)
        let asked = AppKitQuestion(question, in: window)
        asked.alert.layout()
        let field = try XCTUnwrap(asked.alert.accessoryView as? NSTextField)

        XCTAssertFalse(field.isAutomaticTextCompletionEnabled, "the field predicts nothing")
        XCTAssertTrue(asked.alert.window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        XCTAssertFalse(editor.isContinuousSpellCheckingEnabled, "its editor checks no spelling")
        XCTAssertFalse(editor.isAutomaticSpellingCorrectionEnabled, "nor corrects it")
    }
}

#endif
