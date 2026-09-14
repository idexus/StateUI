// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitSearchFieldViewTests: XCTestCase {
    @MainActor
    func testSearchUsesNativeFieldProperties() {
        let search = AppKitSearchFieldView()

        search.apply(
            text: "Ada",
            writeText: true,
            placeholder: "Search",
            placeholderColor: .secondaryLabelColor,
            foregroundColor: .systemPurple,
            backgroundColor: .windowBackgroundColor,
            font: .systemFont(ofSize: 15),
            horizontalAlignment: 1,
            enabled: false,
            readOnly: true,
            maximumLength: 12,
            spellChecking: false,
            textPrediction: false,
            cursorPosition: nil,
            selectionLength: nil,
            writeSelection: false)

        XCTAssertEqual(search.stringValue, "Ada")
        XCTAssertEqual(search.placeholderStringForTesting, "Search")
        XCTAssertEqual(search.font?.pointSize, 15)
        XCTAssertEqual(search.alignment, .center)
        XCTAssertFalse(search.isEnabled)
        XCTAssertFalse(search.isEditable)
        XCTAssertEqual(search.maximumLength, 12)
        XCTAssertTrue(search.sendsWholeSearchString)
    }

    @MainActor
    func testStateWriteIsSilentWhileReaderTextAndSubmitAreSeparate() {
        let search = AppKitSearchFieldView()
        var texts: [String] = []
        var submits = 0
        search.onTextChanged = { texts.append($0) }
        search.onSubmitted = { submits += 1 }

        search.apply(
            text: "tree",
            writeText: true,
            placeholder: nil,
            placeholderColor: nil,
            foregroundColor: .labelColor,
            backgroundColor: nil,
            font: .systemFont(ofSize: 13),
            horizontalAlignment: nil,
            enabled: true,
            readOnly: false,
            maximumLength: 4,
            spellChecking: true,
            textPrediction: true,
            cursorPosition: nil,
            selectionLength: nil,
            writeSelection: false)
        XCTAssertTrue(texts.isEmpty)
        XCTAssertEqual(submits, 0)

        search.typeForTesting("reader")
        search.submitForTesting()

        XCTAssertEqual(search.stringValue, "read")
        XCTAssertEqual(texts, ["read"])
        XCTAssertEqual(submits, 1)
    }

    /// A search field's font family reaches its native field.
    @MainActor
    func testASearchFieldsFontFamilyComesThroughTheHost() throws {
        let renderer = AppKitRenderer.running { SearchField("Ada").fontFamily("Menlo") }
        defer { renderer.closeForTesting() }
        let search = try XCTUnwrap(renderer.nativeViews(AppKitSearchFieldView.self).first)

        XCTAssertEqual(search.font?.familyName, "Menlo")
    }

    /// A read-only search field keeps its text selectable and unchangeable,
    /// and its spell check and word prediction reach the native field and the
    /// editor the reader types into. A field that says nothing keeps all
    /// three on.
    @MainActor
    func testASearchFieldsEditingSettingsComeThroughTheHost() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                SearchField("Plain")
                SearchField("Kept").isReadOnly(true)
                SearchField("Checked").isSpellCheckEnabled(true)
                SearchField("Unchecked").isSpellCheckEnabled(false).isTextPredictionEnabled(false)
            }
        }
        defer { renderer.closeForTesting() }
        let fields = renderer.nativeViews(AppKitSearchFieldView.self)
        XCTAssertEqual(fields.count, 4)
        guard fields.count == 4 else { return }

        XCTAssertEqual(fields.map { $0.isEditable }, [true, false, true, true])
        XCTAssertTrue(fields[1].isSelectable)
        XCTAssertEqual(
            fields.map { $0.isAutomaticTextCompletionEnabled }, [true, true, true, false])
        XCTAssertTrue(try editorChecksSpelling(whileTypingIn: fields[0]))
        XCTAssertTrue(try editorChecksSpelling(whileTypingIn: fields[2]))
        XCTAssertFalse(try editorChecksSpelling(whileTypingIn: fields[3]))
    }

    /// Return in a search field reaches the page's `onSubmitted`.
    @MainActor
    func testReturnInASearchFieldReachesItsSubmitHandler() throws {
        let submitted = Received<String>()
        let renderer = AppKitRenderer.running {
            SearchField("Ada").onSubmitted { submitted.values.append("submitted") }
        }
        defer { renderer.closeForTesting() }
        let search = try XCTUnwrap(renderer.nativeViews(AppKitSearchFieldView.self).first)

        try pressReturn(in: search)

        XCTAssertEqual(submitted.values, ["submitted"])
    }

    /// What a reader types reaches the page's `onTextChanged` handler, the
    /// field's whole text each time.
    @MainActor
    func testTypingInASearchFieldReachesItsTextHandler() throws {
        let texts = Received<String>()
        let renderer = AppKitRenderer.running {
            SearchField("").onTextChanged { texts.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let search = try XCTUnwrap(renderer.nativeViews(AppKitSearchFieldView.self).first)

        search.typeForTesting("a")
        search.typeForTesting("ad")

        XCTAssertEqual(texts.values, ["a", "ad"])
    }
}

#endif
