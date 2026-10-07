// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

final class AppKitSearchFieldViewTests: XCTestCase {
    /// A coloured placeholder stands and is set as the search's words would be: centred where they are, at their
    /// size.
    @MainActor
    func testAColouredPlaceholderStandsAsTheWordsWould() throws {
        let search = AppKitSearchFieldView()
        search.frame = NSRect(x: 0, y: 0, width: 300, height: 44)
        search.apply(
            text: "", writeText: true, placeholder: "WWW", placeholderColor: .red, foregroundColor: .textColor,
            backgroundColor: .white, font: .systemFont(ofSize: 22), horizontalAlignment: 1, enabled: true,
            readOnly: false, maximumLength: nil, traits: InputTraits(spellChecked: false, predicted: false, purpose: nil), cursorPosition: nil,
            selectionLength: nil, writeSelection: false)
        search.layoutSubtreeIfNeeded()

        let ink = try XCTUnwrap(try inkBounds(of: search, where: isRed), "the placeholder is drawn")
        XCTAssertGreaterThan(ink.minX, 90, "centred, not at the leading edge")
        XCTAssertGreaterThan(ink.height, 14, "at the search's 22 points")
    }

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
            traits: InputTraits(spellChecked: false, predicted: false, purpose: nil),
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
    func testStateWriteIsSilentWhileUserTextAndSubmitAreSeparate() {
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
            traits: InputTraits(spellChecked: true, predicted: true, purpose: nil),
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

    /// A field given a colour stands in its bezel's shape filled with it - the search field's capsule, the text
    /// field's rounded box - with no bezel to draw its own ground over the colour, and no square under it.
    @MainActor
    func testAFieldsBackgroundFillsItsShape() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                SearchField("Ada").background(.red)
                TextField("Ada").background(.red)
            }
        }
        defer { renderer.closeForTesting() }
        let search = try XCTUnwrap(renderer.nativeViews(AppKitSearchFieldView.self).first)
        let field = try XCTUnwrap(renderer.nativeViews(AppKitTextFieldView.self).first)

        search.layoutSubtreeIfNeeded()
        field.layoutSubtreeIfNeeded()
        let red = NSColor(red: 1, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(search.fill, red)
        XCTAssertEqual(search.layer?.cornerRadius, search.bounds.height / 2, "the search field's capsule")
        XCTAssertFalse(search.isBezeled, "AppKit's bezel would draw its own ground over the colour")
        XCTAssertEqual(field.fill, red)
        XCTAssertEqual(field.layer?.cornerRadius, AppKitTextEditorView.cornerRadius, "the text field's rounded box")
        XCTAssertFalse(field.textField.isBezeled, "AppKit's bezel would draw its own ground over the colour")
        XCTAssertGreaterThan(field.textField.frame.minX, 0, "its words set in from the box's edge")
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
    /// editor the user types into. A field that says nothing keeps all
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

    /// What a user types reaches the page's `onTextChanged` handler, the
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
