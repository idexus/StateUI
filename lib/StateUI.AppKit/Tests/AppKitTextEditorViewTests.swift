// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitTextEditorViewTests: XCTestCase {
    @MainActor
    func testEditorUsesNativeMultilineTextViewAndScrollView() {
        let editor = AppKitTextEditorView()

        editor.apply(
            text: "First\nSecond",
            writeText: true,
            placeholder: "Notes",
            placeholderColor: .secondaryLabelColor,
            foregroundColor: .systemPurple,
            backgroundColor: .textBackgroundColor,
            font: .systemFont(ofSize: 16),
            horizontalAlignment: 1,
            enabled: true,
            readOnly: false,
            maximumLength: 20,
            spellChecking: false,
            textPrediction: false,
            cursorPosition: nil,
            selectionLength: nil,
            writeSelection: false,
            growsWithText: false)

        XCTAssertEqual(editor.textView.string, "First\nSecond")
        XCTAssertEqual(editor.textView.font?.pointSize, 16)
        XCTAssertEqual(editor.textView.alignment, .center)
        XCTAssertTrue(editor.textView.isEditable)
        XCTAssertTrue(editor.scrollView.hasVerticalScroller)
        XCTAssertEqual(editor.maximumLength, 20)
        XCTAssertEqual(editor.placeholderForTesting, "Notes")
    }

    @MainActor
    func testGrowingEditorDisablesItsOwnVerticalScroller() {
        let editor = AppKitTextEditorView()
        apply(editor, text: "One\nTwo\nThree", growsWithText: true)

        XCTAssertFalse(editor.scrollView.hasVerticalScroller)
        XCTAssertGreaterThan(editor.intrinsicContentSize.height, 0)
    }

    @MainActor
    func testProgramWriteIsSilentAndReaderTypingIsCapped() {
        let editor = AppKitTextEditorView()
        var texts: [String] = []
        editor.onTextChanged = { texts.append($0) }
        apply(editor, text: "tree", maximumLength: 5)
        XCTAssertTrue(texts.isEmpty)

        editor.typeForTesting("reader")

        XCTAssertEqual(editor.textView.string, "reade")
        XCTAssertEqual(texts, ["reade"])
    }

    @MainActor
    private func apply(
        _ editor: AppKitTextEditorView,
        text: String?,
        maximumLength: Int? = nil,
        growsWithText: Bool = false
    ) {
        editor.apply(
            text: text,
            writeText: true,
            placeholder: nil,
            placeholderColor: nil,
            foregroundColor: .labelColor,
            backgroundColor: nil,
            font: .systemFont(ofSize: 13),
            horizontalAlignment: nil,
            enabled: true,
            readOnly: false,
            maximumLength: maximumLength,
            spellChecking: true,
            textPrediction: true,
            cursorPosition: nil,
            selectionLength: nil,
            writeSelection: false,
            growsWithText: growsWithText)
    }
}

#endif
