// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

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
        XCTAssertTrue(view.textField.backgroundColor?.isEqual(NSColor.systemYellow) == true)
        XCTAssertEqual(view.textField.font, font)
        XCTAssertEqual(view.textField.alignment, .center)
        XCTAssertFalse(view.textField.isEnabled)
        XCTAssertFalse(view.textField.isEditable)
        XCTAssertTrue(view.textField.isSelectable)
        XCTAssertEqual(view.maximumLength, 12)
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
