// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A TextField, a SearchField or a TextEditor: an `android.widget.EditText` on one line or several, whose typing
/// reaches Swift through its `StateUIListener`.
/// Design: docs/design/platforms/android/controls.md#a-field-and-its-words
@MainActor
final class AndroidTextFieldView: AndroidTextView {
    /// Which of the three the field is.
    enum Kind {
        /// One line, its return key submitting it.
        case field

        /// One line, its return key captioned for a search.
        case search

        /// Several lines, its return key starting a new one.
        case editor
    }

    /// Which of the three the field is.
    let kind: Kind

    /// What the field does when the user changes its words, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What the field does when the user submits it.
    var onSubmitted: (() -> Void)?

    /// The most characters the user can type; nil for no bound.
    var maximumLength: Int?

    private(set) var isPassword = false
    private var madeHintColors: JavaObject?

    init(_ kind: Kind = .field) {
        self.kind = kind
        super.init { _ in Java.new(JavaAPI.editText, JavaAPI.newEditText, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setInputType, .int(inputType))
        switch kind {
        case .field:
            break
        case .search:
            setReturnKey(nil)
        case .editor:
            Java.call(reference, JavaAPI.setGravity, .int(0x0080_0003 | 0x30))
            Java.call(reference, JavaAPI.setHorizontallyScrolling, .bool(false))
            setGrows(false)
        }
        listen(JavaAPI.addTextChangedListener, JavaAPI.setOnEditorActionListener)
    }

    /// The field's kind of input: one line or several, and hiding what is typed.
    private var inputType: Int32 {
        ViewConstants.textInput | (kind == .editor ? ViewConstants.multiLineInput : 0)
            | (isPassword ? ViewConstants.passwordInput : 0)
    }

    /// What the keyboard's return key does; nil for the kind's own - the platform's, or a search.
    func setReturnKey(_ key: ReturnKey?) {
        // EditorInfo.IME_ACTION_UNSPECIFIED, _GO, _SEARCH, _SEND, _NEXT and _DONE.
        let action: Int32 = switch key ?? (kind == .search ? .search : .default) {
        case .default: 0
        case .go: 2
        case .search: 3
        case .send: 4
        case .next: 5
        case .done: 6
        }
        Java.call(reference, JavaAPI.setImeOptions, .int(action))
    }

    /// Whether an editor grows as its words do: one that does not is one line tall where nothing gives it
    /// room, and scrolls within the room it is given.
    func setGrows(_ grows: Bool) {
        Java.call(reference, JavaAPI.setMaxLines, .int(grows ? Int32.max : 1))
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
        Java.call(reference, JavaAPI.setInputType, .int(inputType))
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
