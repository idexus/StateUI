// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// A TextField, a TextEditor and a SearchField: their words are `TextElementContract.text` and the change they
    /// report is `InputViewContract.textChanged`. Each member reaches the view only where the tree changed it,
    /// which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<WinUIView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = WinUITextFieldView()
            hearInput(field, reports)
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(wordMembers) { view, values in applyWords(view, values) }
            field.applies(boxMembers) { view, values in applyBox(view, values) }
            field.raises(InputViewContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
        registry.add(TextEditorContract.self, create: { reports in
            let editor = WinUITextEditorView()
            hearInput(editor, reports)
            return editor
        }, members: { editor in
            editor.applies(wordMembers) { view, values in applyWords(view, values) }
            editor.applies(boxMembers) { view, values in applyBox(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.growsWithText = grows ?? false }
            editor.raises(InputViewContract.textChanged)
        })
        registry.add(SearchFieldContract.self, create: { reports in
            let search = WinUISearchFieldView()
            hearInput(search, reports)
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(wordMembers) { view, values in applyWords(view, values) }
            search.raises(InputViewContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    private static func hearInput<Realized: ElementContract>(_ view: WinUIInputView, _ reports: Reports<Realized>) {
        view.onTextChanged = { typed in reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged) }
    }

    /// What every view the user types in takes: its words, what it shows while they are none, how many it holds,
    /// whether it takes them, and their font and colour.
    private static let wordMembers: [any ContractMember] = [
        TextElementContract.text, InputViewContract.placeholder, InputViewContract.maximumLength,
        VisualElementContract.isEnabled, FontElementContract.fontSize, FontElementContract.fontAttributes,
        FontElementContract.fontFamily, TextStyleElementContract.textColor,
    ]

    private static func applyWords<Realized: ElementContract>(_ view: WinUIInputView, _ values: ElementValues<Realized>) {
        view.maximumLength = values[InputViewContract.maximumLength].flatMap { $0 > 0 ? $0 : nil }
        if values.changed(TextElementContract.text) { view.setText(values[TextElementContract.text] ?? "") }
        if values.changed(InputViewContract.placeholder) { view.setPlaceholder(values[InputViewContract.placeholder]) }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        if values.changed(FontElementContract.fontSize) || values.changed(FontElementContract.fontAttributes)
            || values.changed(FontElementContract.fontFamily) {
            view.setFont(
                size: values[FontElementContract.fontSize], attributes: values[FontElementContract.fontAttributes],
                family: values[FontElementContract.fontFamily]?.text)
        }
        if values.changed(TextStyleElementContract.textColor) {
            view.setForeground(values[TextStyleElementContract.textColor]?.propValue)
        }
    }

    /// What a text box takes beyond: how it takes words, its words across it, its placeholder's colour, and the
    /// caret and the selection.
    private static let boxMembers: [any ContractMember] = [
        InputViewContract.isReadOnly, InputViewContract.isSpellCheckEnabled, InputViewContract.isTextPredictionEnabled,
        InputViewContract.inputPurpose, TextAlignmentElementContract.horizontalTextAlignment,
        InputViewContract.placeholderColor, InputViewContract.cursorPosition, InputViewContract.selectionLength,
    ]

    private static func applyBox<Realized: ElementContract>(_ view: WinUIInputView, _ values: ElementValues<Realized>) {
        view.setBehaviour(
            readOnly: values[InputViewContract.isReadOnly] ?? false,
            spellChecked: values[InputViewContract.isSpellCheckEnabled] ?? true,
            predicted: values[InputViewContract.isTextPredictionEnabled] ?? true,
            purpose: values[InputViewContract.inputPurpose])
        view.setLook(
            alignment: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
            placeholderColor: values[InputViewContract.placeholderColor]?.propValue)
        if values.changed(InputViewContract.cursorPosition) || values.changed(InputViewContract.selectionLength),
           let caret = values[InputViewContract.cursorPosition] {
            view.select(start: caret, length: values[InputViewContract.selectionLength] ?? 0)
        }
    }
}
