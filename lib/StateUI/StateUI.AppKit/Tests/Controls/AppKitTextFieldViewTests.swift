// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

@MainActor
final class AppKitTextFieldViewTests: XCTestCase {
    /// The render that follows a keystroke carries the typed text back. It
    /// must not move the caret the user is typing at, even when the entry
    /// describes a caret position: only a change of that position moves it.
    @MainActor
    func testReapplyingTheTypedTextKeepsTheUsersCaret() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var entry = HostPatch(id: .manual("entry"), type: .textField)
        entry.properties[.text] = .string("")
        entry.properties[.cursorPosition] = .number(0)
        renderer.applyForTesting(tree(entry))

        let view = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("entry")) as? AppKitTextFieldView)
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

        var typed = HostPatch(id: .manual("entry"), type: .textField)
        typed.properties[.text] = .string("abc")
        renderer.applyForTesting(changedTree(typed))

        XCTAssertEqual(view.textField.stringValue, "abc")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 3, length: 0))
    }

    @MainActor
    func testAnEntryUsesNativeTextFieldProperties() {
        let view = AppKitTextFieldView()
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
        XCTAssertTrue(view.fill?.isEqual(NSColor.systemYellow) == true)
        XCTAssertFalse(view.textField.isBezeled, "a colour stands in the bezel's shape, filled with it")
        XCTAssertEqual(view.textField.font, font)
        XCTAssertEqual(view.textField.alignment, .center)
        XCTAssertFalse(view.textField.isEnabled)
        XCTAssertFalse(view.textField.isEditable)
        XCTAssertTrue(view.textField.isSelectable)
        XCTAssertEqual(view.maximumLength, 12)
    }

    /// A coloured placeholder stands and is set as the field's words would be: centred where they are, at their size.
    @MainActor
    func testAColouredPlaceholderStandsAsTheWordsWould() throws {
        let view = AppKitTextFieldView()
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 44)
        apply(
            view, text: "", placeholder: "WWW", placeholderColor: .red, backgroundColor: .white,
            font: .systemFont(ofSize: 22), horizontalAlignment: 1)
        view.layoutSubtreeIfNeeded()

        let ink = try XCTUnwrap(try inkBounds(of: view, where: isRed), "the placeholder is drawn")
        XCTAssertGreaterThan(ink.minX, 90, "centred, not at the leading edge")
        XCTAssertGreaterThan(ink.height, 14, "at the field's 22 points")
    }

    /// Plain words are taken as typed: the editor a user types in corrects, replaces and marks nothing, and the text
    /// checking it asks for as the user types puts no capital in - whatever the user's own setting.
    @MainActor
    func testPlainWordsAreTakenAsTyped() throws {
        let view = AppKitTextFieldView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.titled], backing: .buffered,
            defer: false)
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 30)
        window.contentView?.addSubview(view)
        apply(view, text: "", traits: InputTraits(spellChecked: true, predicted: true, purpose: .plain))
        XCTAssertTrue(window.makeFirstResponder(view.textField))
        let editor = try XCTUnwrap(view.textField.currentEditor() as? NSTextView)
        editor.insertText("a", replacementRange: editor.selectedRange())

        XCTAssertFalse(editor.isAutomaticSpellingCorrectionEnabled)
        XCTAssertFalse(editor.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(editor.isContinuousSpellCheckingEnabled)
        XCTAssertEqual(try checking(asked: editor)[.automaticCapitalizationEnabledKey] as? Bool, false)
    }

    /// Text starts its sentences in capitals, whatever the user's own setting; the default says nothing of them.
    @MainActor
    func testTextStartsItsSentencesInCapitals() throws {
        let view = AppKitTextFieldView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.titled], backing: .buffered,
            defer: false)
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 30)
        window.contentView?.addSubview(view)
        apply(view, text: "", traits: InputTraits(spellChecked: true, predicted: true, purpose: .text))
        XCTAssertTrue(window.makeFirstResponder(view.textField))
        let editor = try XCTUnwrap(view.textField.currentEditor() as? NSTextView)
        XCTAssertEqual(try checking(asked: editor)[.automaticCapitalizationEnabledKey] as? Bool, true)

        apply(view, text: "", traits: InputTraits(spellChecked: true, predicted: true, purpose: nil))
        XCTAssertNil(try checking(asked: editor)[.automaticCapitalizationEnabledKey])
    }

    /// The options the text checking an editor runs as the user types is given, as the editor asks its delegate.
    @MainActor
    private func checking(asked editor: NSTextView) throws -> [NSSpellChecker.OptionKey: Any] {
        let delegate = try XCTUnwrap(editor.delegate)
        var types = editor.enabledTextCheckingTypes
        return delegate.textView?(editor, willCheckTextIn: NSRange(location: 0, length: 0), options: [:], types: &types)
            ?? [:]
    }

    @MainActor
    func testPasswordChangesTheNativeEditorWithoutLosingText() {
        let view = AppKitTextFieldView()
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
        let view = AppKitTextFieldView()
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
        let view = AppKitTextFieldView()
        var reports: [String] = []
        view.onTextChanged = { reports.append($0) }
        apply(view, text: "Ada")

        view.setText("Grace")

        XCTAssertEqual(view.textField.stringValue, "Grace")
        XCTAssertTrue(reports.isEmpty)
    }

    /// A field's font family reaches its native field.
    @MainActor
    func testATextFieldsFontFamilyComesThroughTheHost() throws {
        let renderer = AppKitRenderer.running { TextField("Ada").fontFamily("Menlo") }
        defer { renderer.closeForTesting() }
        let field = try XCTUnwrap(renderer.nativeViews(AppKitTextFieldView.self).first)

        XCTAssertEqual(field.textField.font?.familyName, "Menlo")
    }

    /// A read-only field keeps its text selectable and unchangeable, and a
    /// field's spell check and word prediction reach the native field and
    /// the editor the user types into. A field that says nothing keeps
    /// all three on.
    @MainActor
    func testATextFieldsEditingSettingsComeThroughTheHost() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                TextField("Plain")
                TextField("Kept").isReadOnly(true)
                TextField("Checked").isSpellCheckEnabled(true)
                TextField("Unchecked").isSpellCheckEnabled(false).isTextPredictionEnabled(false)
            }
        }
        defer { renderer.closeForTesting() }
        let fields = renderer.nativeViews(AppKitTextFieldView.self).map { $0.textField }
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

    /// Return in a field reaches the page's `onSubmitted`.
    @MainActor
    func testReturnInATextFieldReachesItsSubmitHandler() throws {
        let submitted = Received<String>()
        let renderer = AppKitRenderer.running {
            TextField("Ada").onSubmitted { submitted.values.append("submitted") }
        }
        defer { renderer.closeForTesting() }
        let field = try XCTUnwrap(renderer.nativeViews(AppKitTextFieldView.self).first)

        try pressReturn(in: field.textField)

        XCTAssertEqual(submitted.values, ["submitted"])
    }

    /// What a user types reaches the page's `onTextChanged` handler, the
    /// field's whole text each time.
    @MainActor
    func testTypingInATextFieldReachesItsTextHandler() throws {
        let texts = Received<String>()
        let renderer = AppKitRenderer.running {
            TextField("").onTextChanged { texts.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let field = try XCTUnwrap(renderer.nativeViews(AppKitTextFieldView.self).first)

        field.typeForTesting("a")
        field.typeForTesting("ad")

        XCTAssertEqual(texts.values, ["a", "ad"])
    }

    @MainActor
    private func apply(
        _ view: AppKitTextFieldView,
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
        maximumLength: Int? = nil,
        traits: InputTraits = InputTraits(spellChecked: true, predicted: true, purpose: nil)
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
            traits: traits,
            cursorPosition: nil,
            selectionLength: nil,
            writeSelection: false)
    }
}

#endif
