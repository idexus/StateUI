// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitEntryViewTests: XCTestCase {
    /// The render that follows a keystroke carries the typed text back. It
    /// must not move the caret the reader is typing at, even when the entry
    /// describes a caret position: only a change of that position moves it.
    @MainActor
    func testReapplyingTheTypedTextKeepsTheReadersCaret() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var entry = HostPatch(id: .manual("entry"), type: .entry)
        entry.properties[.text] = .string("")
        entry.properties[.cursorPosition] = .number(0)
        renderer.applyForTesting(tree(entry))

        let view = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("entry")) as? AppKitEntryView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: .titled,
            backing: .buffered,
            defer: false)
        view.frame = NSRect(x: 10, y: 10, width: 200, height: 24)
        window.contentView?.addSubview(view)
        XCTAssertTrue(window.makeFirstResponder(view.textField))
        let editor = try XCTUnwrap(view.textField.currentEditor() as? NSTextView)
        editor.insertText("abc", replacementRange: editor.selectedRange())

        var typed = HostPatch(id: .manual("entry"), type: .entry)
        typed.properties[.text] = .string("abc")
        renderer.applyForTesting(changedTree(typed))

        XCTAssertEqual(view.textField.stringValue, "abc")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 3, length: 0))
    }

    @MainActor
    func testAnEntryUsesNativeTextFieldProperties() {
        let view = AppKitEntryView()
        let font = NSFont.systemFont(ofSize: 18, weight: .bold)

        apply(
            view,
            text: "Ada",
            placeholder: "Name",
            placeholderColor: .systemGray,
            foregroundColor: .systemBlue,
            backgroundColor: .systemYellow,
            font: font,
            horizontalAlignment: 1,
            enabled: false,
            readOnly: true,
            maximumLength: 12)

        XCTAssertEqual(view.textField.stringValue, "Ada")
        XCTAssertEqual(view.textField.placeholderAttributedString?.string, "Name")
        XCTAssertTrue(view.textField.textColor?.isEqual(NSColor.systemBlue) == true)
        XCTAssertTrue(view.textField.backgroundColor?.isEqual(NSColor.systemYellow) == true)
        XCTAssertEqual(view.textField.font, font)
        XCTAssertEqual(view.textField.alignment, .center)
        XCTAssertFalse(view.textField.isEnabled)
        XCTAssertFalse(view.textField.isEditable)
        XCTAssertTrue(view.textField.isSelectable)
        XCTAssertEqual(view.maxLength, 12)
    }

    @MainActor
    func testPasswordChangesTheNativeEditorWithoutLosingText() {
        let view = AppKitEntryView()
        apply(view, text: "secret")

        apply(view, text: nil, writeText: false, secure: true)

        XCTAssertTrue(view.textField is NSSecureTextField)
        XCTAssertTrue(view.isSecure)
        XCTAssertEqual(view.textField.stringValue, "secret")

        apply(view, text: nil, writeText: false, secure: false)

        XCTAssertFalse(view.textField is NSSecureTextField)
        XCTAssertFalse(view.isSecure)
        XCTAssertEqual(view.textField.stringValue, "secret")
    }

    @MainActor
    func testTypingIsCappedAndReportedAsTheWholeText() {
        let view = AppKitEntryView()
        var reports: [String] = []
        view.onTextChanged = { reports.append($0) }
        apply(view, text: "", maximumLength: 4)

        view.textField.stringValue = "Grace"
        view.controlTextDidChange(Notification(name: .init("test"), object: view.textField))

        XCTAssertEqual(view.textField.stringValue, "Grac")
        XCTAssertEqual(reports, ["Grac"])
    }

    @MainActor
    func testAStateWriteDoesNotBecomeAUserReport() {
        let view = AppKitEntryView()
        var reports: [String] = []
        view.onTextChanged = { reports.append($0) }
        apply(view, text: "Ada")

        view.setText("Grace")

        XCTAssertEqual(view.textField.stringValue, "Grace")
        XCTAssertTrue(reports.isEmpty)
    }

    @MainActor
    private func apply(
        _ view: AppKitEntryView,
        text: String?,
        writeText: Bool = true,
        placeholder: String? = nil,
        placeholderColor: NSColor? = nil,
        foregroundColor: NSColor = .controlTextColor,
        backgroundColor: NSColor? = nil,
        font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
        horizontalAlignment: Int32? = nil,
        enabled: Bool = true,
        readOnly: Bool = false,
        secure: Bool = false,
        maximumLength: Int? = nil
    ) {
        view.apply(
            text: text,
            writeText: writeText,
            placeholder: placeholder,
            placeholderColor: placeholderColor,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
            font: font,
            horizontalAlignment: horizontalAlignment,
            enabled: enabled,
            readOnly: readOnly,
            secure: secure,
            maximumLength: maximumLength,
            spellChecking: true,
            textPrediction: true,
            cursorPosition: nil,
            selectionLength: nil,
            writeSelection: false)
    }
}

#endif
