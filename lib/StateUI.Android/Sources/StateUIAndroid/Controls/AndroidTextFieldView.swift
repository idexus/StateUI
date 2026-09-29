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

    /// The case the field holds its words in; nil for as they are typed.
    var textCase: TextCase?

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

    /// Whether an editor grows as its words do: one that does not is exactly a line tall where nothing gives it
    /// room, whatever its words, and scrolls within the room it is given.
    func setGrows(_ grows: Bool) {
        self.grows = grows
        Java.call(reference, JavaAPI.setMaxLines, .int(grows ? Int32.max : 1))
    }

    /// Whether the editor grows as its words do.
    private var grows = true

    /// An editor that does not grow stands a line tall - a line laid out alone, whatever its words hold - where
    /// the tree states no height: Android's layout gives the first of several lines less than a line alone.
    /// Design: docs/design/platforms/android/controls.md#an-editor-a-line-tall
    override func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        let measured = super.measure(width: width, height: height)
        guard kind == .editor, !grows, ViewConstants.mode(height) != ViewConstants.exactly else { return measured }

        let line = Java.frame { () -> Int32 in
            guard let paint = Java.callObject(reference, JavaAPI.getPaint),
                  let metrics = Java.callObject(paint, JavaAPI.getFontMetricsInt)
            else { return 0 }
            return Java.callBool(reference, JavaAPI.getIncludeFontPadding)
                ? Java.int(metrics, JavaAPI.metricsBottom) - Java.int(metrics, JavaAPI.metricsTop)
                : Java.int(metrics, JavaAPI.metricsDescent) - Java.int(metrics, JavaAPI.metricsAscent)
        }
        let tall = line + Java.callInt(reference, JavaAPI.getCompoundPaddingTop)
            + Java.callInt(reference, JavaAPI.getCompoundPaddingBottom)
        let bounded = ViewConstants.mode(height) == ViewConstants.atMost ? min(tall, ViewConstants.size(height)) : tall
        return (measured.width, bounded)
    }

    /// Writes the words where they differ from the field's, with the caret after them.
    override func setText(_ text: String) {
        guard text != self.text else { return }

        super.setText(text)
        let end = Int32(text.utf16.count)
        Java.call(reference, JavaAPI.setSelection, .int(end), .int(end))
    }

    /// The user changed the words: held in the field's case within `maximumLength` (`InputWords.held`), then handed
    /// on.
    func typed(_ text: String) {
        guard !ProgramWrite.isWriting else { return }

        var kept = text
        if let held = InputWords.held(text, in: textCase, toBound: maximumLength) {
            kept = held
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
        let selection = InputWords.utf16Selection(start: position, length: length, in: text)
        Java.call(
            reference, JavaAPI.setSelection, .int(Int32(selection.start)),
            .int(Int32(selection.start + selection.length)))
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
        onSubmitted = nil
    }
}
