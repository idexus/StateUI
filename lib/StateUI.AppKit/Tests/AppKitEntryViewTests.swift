// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitEntryViewTests: XCTestCase {
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
            selectionLength: nil)
    }
}

#endif
