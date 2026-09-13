// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native single-line text field that can change between ordinary and
/// secure AppKit editors without changing the StateUI element's identity.
@MainActor
final class AppKitEntryView: NSView, NSTextFieldDelegate {
    private(set) var textField: NSTextField
    private(set) var isSecure = false
    private(set) var maxLength: Int?

    var onTextChanged: ((String) -> Void)?
    var onCompleted: (() -> Void)?

    private var writing = false
    private var spellChecking = true
    private var textPrediction = true
    private var cursorPosition: Int?
    private var selectionLength: Int?

    override init(frame frameRect: NSRect) {
        textField = NSTextField()
        super.init(frame: frameRect)
        install(textField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitEntryView is created in code")
    }

    override var intrinsicContentSize: NSSize { textField.intrinsicContentSize }

    override func layout() {
        super.layout()
        textField.frame = bounds
    }

    /// Applies the StateUI properties that have direct AppKit semantics.
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
        secure: Bool,
        maximumLength: Int?,
        spellChecking: Bool,
        textPrediction: Bool,
        cursorPosition: Int?,
        selectionLength: Int?
    ) {
        if secure != isSecure {
            replaceTextField(secure: secure)
        }

        maxLength = maximumLength.map { max(0, $0) }
        self.spellChecking = spellChecking
        self.textPrediction = textPrediction
        self.cursorPosition = cursorPosition
        self.selectionLength = selectionLength

        textField.placeholderString = nil
        textField.placeholderAttributedString = nil

        if let placeholderColor, let placeholder {
            textField.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor])
        } else {
            textField.placeholderString = placeholder
        }

        textField.textColor = foregroundColor
        textField.font = font
        textField.isEnabled = enabled
        textField.isEditable = !readOnly
        textField.isSelectable = true
        textField.isAutomaticTextCompletionEnabled = textPrediction
        textField.alignment = alignment(horizontalAlignment)

        if let backgroundColor {
            textField.drawsBackground = true
            textField.backgroundColor = backgroundColor
        } else {
            textField.drawsBackground = true
            textField.backgroundColor = .textBackgroundColor
        }

        if writeText, let text {
            setText(text)
        }

        applyEditorPreferences()
        applySelection()
        invalidateIntrinsicContentSize()
    }

    /// Writes text from StateUI without turning that write into a user report.
    func setText(_ text: String) {
        guard textField.stringValue != text else { return }

        writing = true
        textField.stringValue = text

        if let editor = textField.currentEditor() {
            editor.string = text
        }

        writing = false
        applySelection()
        invalidateIntrinsicContentSize()
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        applyEditorPreferences()
        applySelection()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !writing else { return }

        let typed = limited(textField.stringValue)

        if typed != textField.stringValue {
            writing = true
            textField.stringValue = typed

            if let editor = textField.currentEditor() {
                editor.string = typed
                editor.selectedRange = NSRange(location: typed.utf16.count, length: 0)
            }

            writing = false
        }

        onTextChanged?(typed)
    }

    @objc func completed(_ sender: NSTextField) {
        onCompleted?()
    }

    private func install(_ field: NSTextField) {
        field.delegate = self
        field.target = self
        field.action = #selector(completed(_:))
        field.maximumNumberOfLines = 1
        field.translatesAutoresizingMaskIntoConstraints = true
        field.autoresizingMask = [.width, .height]
        addSubview(field)
    }

    private func replaceTextField(secure: Bool) {
        let previous = textField
        let words = previous.stringValue
        let wasFirstResponder = window?.firstResponder === previous.currentEditor()
            || window?.firstResponder === previous
        let replacement: NSTextField = secure ? NSSecureTextField() : NSTextField()

        previous.removeFromSuperview()
        textField = replacement
        isSecure = secure
        install(replacement)
        replacement.frame = bounds
        replacement.stringValue = words

        if wasFirstResponder {
            window?.makeFirstResponder(replacement)
        }
    }

    private func applyEditorPreferences() {
        guard let editor = textField.currentEditor() as? NSTextView else { return }

        editor.isContinuousSpellCheckingEnabled = spellChecking
        editor.isAutomaticTextCompletionEnabled = textPrediction
    }

    private func applySelection() {
        guard let editor = textField.currentEditor(),
              cursorPosition != nil || selectionLength != nil
        else { return }

        let text = editor.string
        let start = utf16Offset(of: max(0, cursorPosition ?? 0), in: text)
        let end = utf16Offset(
            of: max(0, cursorPosition ?? 0) + max(0, selectionLength ?? 0),
            in: text)
        editor.selectedRange = NSRange(location: start, length: max(0, end - start))
    }

    private func limited(_ text: String) -> String {
        guard let maxLength, text.count > maxLength else { return text }
        return String(text.prefix(maxLength))
    }

    private func utf16Offset(of characterOffset: Int, in text: String) -> Int {
        let offset = min(characterOffset, text.count)
        let index = text.index(text.startIndex, offsetBy: offset)
        return index.utf16Offset(in: text)
    }

    private func alignment(_ value: Int32?) -> NSTextAlignment {
        switch value {
        case 1:
            return .center
        case 2:
            return userInterfaceLayoutDirection == .rightToLeft ? .left : .right
        default:
            return userInterfaceLayoutDirection == .rightToLeft ? .right : .left
        }
    }
}

#endif
