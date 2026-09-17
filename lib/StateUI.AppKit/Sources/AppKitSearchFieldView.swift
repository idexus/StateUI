// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// AppKit's native search field with separate edit and submit reports.
@MainActor
final class AppKitSearchFieldView: NSSearchField, NSSearchFieldDelegate {
    var onTextChanged: ((String) -> Void)?
    var onSubmitted: (() -> Void)?
    private(set) var maximumLength: Int?

    private var writing = false
    private var spellChecking = true
    private var textPrediction = true
    private var cursorPosition: Int?
    private var selectionLength: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        delegate = self
        target = self
        action = #selector(submitted(_:))
        sendsWholeSearchString = true
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSearchFieldView is created in code")
    }

    func apply(
        text: String?,
        writeText: Bool,
        placeholder: String?,
        placeholderColor: NSColor?,
        foregroundColor: NSColor,
        backgroundColor: NSColor?,
        font: NSFont,
        horizontalAlignment: Int32?,
        enabled: Bool,
        readOnly: Bool,
        maximumLength: Int?,
        spellChecking: Bool,
        textPrediction: Bool,
        cursorPosition: Int?,
        selectionLength: Int?,
        writeSelection: Bool
    ) {
        self.maximumLength = maximumLength.map { max(0, $0) }
        self.spellChecking = spellChecking
        self.textPrediction = textPrediction
        self.cursorPosition = cursorPosition
        self.selectionLength = selectionLength

        placeholderString = nil
        placeholderAttributedString = nil
        if let placeholderColor, let placeholder {
            placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor])
        } else {
            placeholderString = placeholder
        }

        textColor = foregroundColor
        self.font = font
        isEnabled = enabled
        isEditable = !readOnly
        isSelectable = true
        isAutomaticTextCompletionEnabled = textPrediction
        alignment = nativeAlignment(horizontalAlignment)

        drawsBackground = true
        self.backgroundColor = backgroundColor ?? .textBackgroundColor

        if writeText, let text { setText(text) }

        applyEditorPreferences()
        if writeSelection { applySelection() }
    }

    func setText(_ text: String) {
        guard stringValue != text else { return }
        writing = true
        stringValue = text
        currentEditor()?.string = text
        writing = false
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        applyEditorPreferences()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !writing else { return }
        let typed = limited(stringValue)

        if typed != stringValue {
            writing = true
            stringValue = typed
            if let editor = currentEditor() {
                editor.string = typed
                editor.selectedRange = NSRange(location: typed.utf16.count, length: 0)
            }
            writing = false
        }

        onTextChanged?(typed)
    }

    @objc private func submitted(_ sender: NSSearchField) {
        onSubmitted?()
    }

    private func applyEditorPreferences() {
        guard let editor = currentEditor() as? NSTextView else { return }
        editor.isContinuousSpellCheckingEnabled = spellChecking
        editor.isAutomaticTextCompletionEnabled = textPrediction
    }

    /// Only a change of the authored selection moves the caret. A text write,
    /// including the one that carries the reader's own typing back, leaves
    /// the caret where the reader put it.
    private func applySelection() {
        guard let editor = currentEditor(),
              cursorPosition != nil || selectionLength != nil
        else { return }

        let words = editor.string
        let start = utf16Offset(of: max(0, cursorPosition ?? 0), in: words)
        let end = utf16Offset(
            of: max(0, cursorPosition ?? 0) + max(0, selectionLength ?? 0),
            in: words)
        editor.selectedRange = NSRange(location: start, length: max(0, end - start))
    }

    private func limited(_ text: String) -> String {
        guard let maximumLength, text.count > maximumLength else { return text }
        return String(text.prefix(maximumLength))
    }

    private func utf16Offset(of characterOffset: Int, in text: String) -> Int {
        let offset = min(characterOffset, text.count)
        let index = text.index(text.startIndex, offsetBy: offset)
        return index.utf16Offset(in: text)
    }

    private func nativeAlignment(_ value: Int32?) -> NSTextAlignment {
        switch value {
        case 1:
            return .center
        case 2:
            return userInterfaceLayoutDirection == .rightToLeft ? .left : .right
        default:
            return userInterfaceLayoutDirection == .rightToLeft ? .right : .left
        }
    }

    var placeholderStringForTesting: String? {
        placeholderAttributedString?.string ?? placeholderString
    }

    func typeForTesting(_ text: String) {
        stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    func submitForTesting() {
        submitted(self)
    }
}

#endif
