// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A TextField, a TextEditor and a SearchField: their words are `TextElementContract.text` and the change they
    /// report is `InputViewContract.textChanged`. Each member reaches the view only where the tree changed it,
    /// which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<GTKView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = GTKTextFieldView()
            hearInput(field, reports)
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(inputMembers) { view, values in applyInput(view, values) }
            field.property(TextFieldContract.isPassword) { view, hidden in view.setPassword(hidden ?? false) }
            field.raises(InputViewContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
        registry.add(TextEditorContract.self, create: { reports in
            let editor = GTKTextEditorView()
            hearInput(editor, reports)
            return editor
        }, members: { editor in
            editor.applies(inputMembers) { view, values in applyInput(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.setGrowsWithText(grows ?? false) }
            editor.raises(InputViewContract.textChanged)
        })
        registry.add(SearchFieldContract.self, create: { reports in
            let search = GTKSearchFieldView()
            hearInput(search, reports)
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(inputMembers) { view, values in applyInput(view, values) }
            search.raises(InputViewContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    private static func hearInput<Realized: ElementContract>(_ view: any GTKInputView, _ reports: Reports<Realized>) {
        view.onTextChanged = { typed in reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged) }
    }

    /// What every view the user types in takes: its words, their bound and what shows while they are none, whether
    /// and how it takes them, their look and where they stand, and the caret and the selection.
    private static let inputMembers: [any ContractMember] = [
        TextElementContract.text, InputViewContract.placeholder, InputViewContract.maximumLength,
        VisualElementContract.isEnabled, InputViewContract.isReadOnly, InputViewContract.isSpellCheckEnabled,
        InputViewContract.isTextPredictionEnabled, InputViewContract.inputPurpose, FontElementContract.fontSize,
        FontElementContract.fontAttributes, FontElementContract.fontFamily, TextStyleElementContract.textColor,
        InputViewContract.placeholderColor, TextAlignmentElementContract.horizontalTextAlignment,
        InputViewContract.cursorPosition, InputViewContract.selectionLength,
    ]

    private static func applyInput<Realized: ElementContract>(_ view: any GTKInputView, _ values: ElementValues<Realized>) {
        if values.changed(InputViewContract.maximumLength) {
            view.setMaximumLength(values[InputViewContract.maximumLength].flatMap { $0 > 0 ? $0 : nil })
        }
        if values.changed(TextElementContract.text) { view.setText(values[TextElementContract.text] ?? "") }
        if values.changed(InputViewContract.placeholder) { view.setPlaceholder(values[InputViewContract.placeholder]) }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        if values.changed(InputViewContract.isReadOnly) || values.changed(InputViewContract.isSpellCheckEnabled)
            || values.changed(InputViewContract.isTextPredictionEnabled) || values.changed(InputViewContract.inputPurpose) {
            let (hints, purpose) = GTKTextFieldView.input(
                spellChecked: values[InputViewContract.isSpellCheckEnabled] ?? true,
                predicted: values[InputViewContract.isTextPredictionEnabled] ?? true,
                purpose: values[InputViewContract.inputPurpose])
            view.setBehaviour(readOnly: values[InputViewContract.isReadOnly] ?? false, hints: hints, purpose: purpose)
        }
        if values.changed(FontElementContract.fontSize) || values.changed(FontElementContract.fontAttributes)
            || values.changed(FontElementContract.fontFamily) || values.changed(TextStyleElementContract.textColor)
            || values.changed(InputViewContract.placeholderColor) {
            var look = TextLook()
            look.size = values[FontElementContract.fontSize]
            look.attributes = values[FontElementContract.fontAttributes] ?? .none
            look.family = values[FontElementContract.fontFamily]?.text
            look.color = values[TextStyleElementContract.textColor]?.propValue
            view.setWordsClass(GTKStyleSheet.words(
                look, placeholder: values[InputViewContract.placeholderColor].flatMap { GTKBrush.rgba($0.propValue) }))
        }
        if values.changed(TextAlignmentElementContract.horizontalTextAlignment) {
            view.setAlignment(values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
        }
        if values.changed(InputViewContract.cursorPosition) || values.changed(InputViewContract.selectionLength),
           let caret = values[InputViewContract.cursorPosition] {
            view.select(start: caret, length: values[InputViewContract.selectionLength] ?? 0)
        }
    }
}
