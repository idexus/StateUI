// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
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
    func testProgramWriteIsSilentAndUserTypingIsCapped() {
        let editor = AppKitTextEditorView()
        var texts: [String] = []
        editor.onTextChanged = { texts.append($0) }
        apply(editor, text: "tree", maximumLength: 5)
        XCTAssertTrue(texts.isEmpty)

        editor.typeForTesting("reader")

        XCTAssertEqual(editor.textView.string, "reade")
        XCTAssertEqual(texts, ["reade"])
    }

    /// An editor's font family reaches its native text view.
    @MainActor
    func testATextEditorsFontFamilyComesThroughTheHost() throws {
        let renderer = AppKitRenderer.running { TextEditor("Ada").fontFamily("Menlo") }
        defer { renderer.closeForTesting() }
        let editor = try XCTUnwrap(renderer.nativeViews(AppKitTextEditorView.self).first)

        XCTAssertEqual(editor.textView.font?.familyName, "Menlo")
    }

    /// A read-only editor cannot be changed, and an editor's spell check and
    /// word prediction reach its native text view. An editor that says
    /// nothing keeps all three on.
    @MainActor
    func testATextEditorsEditingSettingsComeThroughTheHost() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                TextEditor("Plain")
                TextEditor("Set")
                    .isReadOnly(true)
                    .isSpellCheckEnabled(false)
                    .isTextPredictionEnabled(false)
            }
        }
        defer { renderer.closeForTesting() }
        let texts = renderer.nativeViews(AppKitTextEditorView.self).map { $0.textView }

        XCTAssertEqual(texts.map { $0.isEditable }, [true, false])
        XCTAssertEqual(texts.map { $0.isContinuousSpellCheckingEnabled }, [true, false])
        XCTAssertEqual(texts.map { $0.isAutomaticTextCompletionEnabled }, [true, false])
    }

    /// What a user types reaches the page's `onTextChanged` handler, the
    /// editor's whole text each time.
    @MainActor
    func testTypingInATextEditorReachesItsTextHandler() throws {
        let texts = Received<String>()
        let renderer = AppKitRenderer.running {
            TextEditor("").onTextChanged { texts.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let editor = try XCTUnwrap(renderer.nativeViews(AppKitTextEditorView.self).first)

        editor.typeForTesting("a")
        editor.typeForTesting("ab")

        XCTAssertEqual(texts.values, ["a", "ab"])
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
