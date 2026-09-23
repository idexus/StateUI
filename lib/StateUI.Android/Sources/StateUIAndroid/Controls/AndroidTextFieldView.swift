// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A TextField: an `android.widget.EditText` on one line, whose typing reaches Swift through its `StateUIListener`.
/// Design: docs/design/platforms/android/controls.md#a-field-and-its-words
@MainActor
final class AndroidTextFieldView: AndroidTextView {
    /// What the field does when the user changes its words, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What the field does when the user submits it.
    var onSubmitted: (() -> Void)?

    /// The most characters the user can type; nil for no bound.
    var maximumLength: Int?

    private(set) var isPassword = false
    private var madeHintColors: JavaObject?

    init() {
        super.init { _ in Java.new(JavaAPI.editText, JavaAPI.newEditText, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setInputType, .int(ViewConstants.textInput))
        listen(JavaAPI.addTextChangedListener, JavaAPI.setOnEditorActionListener)
    }

    /// Writes the words where they differ from the field's, with the caret after them.
    override func setText(_ text: String) {
        guard text != self.text else { return }

        super.setText(text)
        let end = Int32(text.utf16.count)
        Java.call(reference, JavaAPI.setSelection, .int(end), .int(end))
    }

    /// The user changed the words: kept within `maximumLength`, then handed on.
    func typed(_ text: String) {
        guard !ProgramWrite.isWriting else { return }

        var kept = text
        if let maximumLength, text.count > maximumLength {
            kept = String(text.prefix(maximumLength))
            ProgramWrite.perform { setText(kept) }
        }
        onTextChanged?(kept)
    }

    /// The words shown while there are none.
    func setPlaceholder(_ placeholder: String?) {
        let hint = placeholder.flatMap(Java.string)
        Java.call(reference, JavaAPI.setHint, .object(hint))
        Java.release(local: hint)
    }

    /// The placeholder's colour; nil puts back the platform's.
    func setPlaceholderColor(_ color: HostValue?) {
        if madeHintColors == nil {
            madeHintColors = JavaObject(Java.callObject(reference, JavaAPI.getHintTextColors)!)
        }

        if let argb = color.flatMap(Self.argb) {
            Java.call(reference, JavaAPI.setHintTextColor, .int(argb))
        } else {
            Java.call(reference, JavaAPI.setHintTextColors, .object(madeHintColors!.reference))
        }
    }

    /// Hides what is typed, or shows it; the words and their weight stay.
    func setPassword(_ password: Bool) {
        guard password != isPassword else { return }

        isPassword = password
        let kind = ViewConstants.textInput | (password ? ViewConstants.passwordInput : 0)
        Java.call(reference, JavaAPI.setInputType, .int(kind))
        setFontAttributes(fontAttributes)
    }

    /// Selects `length` characters from `position`: a caret where `length` is zero.
    func select(from position: Int, length: Int) {
        let words = text
        func offset(_ characters: Int) -> Int32 {
            Int32(words.prefix(max(0, characters)).utf16.count)
        }

        Java.call(reference, JavaAPI.setSelection, .int(offset(position)), .int(offset(position + max(0, length))))
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
        onSubmitted = nil
    }
}
