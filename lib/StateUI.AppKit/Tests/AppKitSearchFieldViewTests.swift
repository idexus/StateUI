// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
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
}

#endif
