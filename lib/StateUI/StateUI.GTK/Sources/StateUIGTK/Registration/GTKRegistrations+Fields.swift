// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A TextField, a TextEditor and a SearchField: their words are `TextualElementContract.text` and the change they
    /// report is `TextInputContract.textChanged`. Each member reaches the view only where the tree changed it,
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
            field.raises(TextInputContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
        registry.add(TextEditorContract.self, create: { reports in
            let editor = GTKTextEditorView()
            hearInput(editor, reports)
            return editor
        }, members: { editor in
            editor.applies(inputMembers) { view, values in applyInput(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.setGrowsWithText(grows ?? false) }
            editor.raises(TextInputContract.textChanged)
        })
        registry.add(SearchFieldContract.self, create: { reports in
            let search = GTKSearchFieldView()
            hearInput(search, reports)
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(inputMembers) { view, values in applyInput(view, values) }
            search.raises(TextInputContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    private static func hearInput<Realized: ElementContract>(_ view: any GTKTextInputView, _ reports: Reports<Realized>) {
        view.onTextChanged = { typed in reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged) }
    }

    /// What every view the user types in takes: its words, their bound and what shows while they are none, whether
    /// and how it takes them, their look and where they stand, and the caret and the selection.
    private static let inputMembers: [any ContractMember] = [
        TextualElementContract.text, TextualElementContract.textCase, TextInputContract.placeholder,
        TextInputContract.maximumLength,
        VisualElementContract.isEnabled, TextInputContract.isReadOnly, TextInputContract.isSpellCheckEnabled,
        TextInputContract.isTextPredictionEnabled, TextInputContract.inputPurpose, FontElementContract.fontSize,
        FontElementContract.fontAttributes, FontElementContract.fontFamily, TextStyleElementContract.textColor,
        TextInputContract.placeholderColor, TextAlignmentElementContract.horizontalTextAlignment,
        TextInputContract.cursorPosition, TextInputContract.selectionLength,
    ]

    private static func applyInput<Realized: ElementContract>(_ view: any GTKTextInputView, _ values: ElementValues<Realized>) {
        if values.changed(TextInputContract.maximumLength) {
            view.setMaximumLength(values[TextInputContract.maximumLength].flatMap { $0 > 0 ? $0 : nil })
        }
        if values.changed(TextualElementContract.textCase) { view.setTextCase(values[TextualElementContract.textCase]) }
        if values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase) {
            let textCase = values[TextualElementContract.textCase] ?? .none
            view.setText(textCase.applied(to: values[TextualElementContract.text] ?? ""))
        }
        if values.changed(TextInputContract.placeholder) { view.setPlaceholder(values[TextInputContract.placeholder]) }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        if values.changed(TextInputContract.isReadOnly) || InputTraits.changed(values) != nil {
            let (hints, purpose) = GTKTextFieldView.input(InputTraits(values))
            view.setBehaviour(readOnly: values[TextInputContract.isReadOnly] ?? false, hints: hints, purpose: purpose)
        }
        if TextMembers.look(values) != nil || values.changed(TextInputContract.placeholderColor) {
            view.setWordsClass(GTKStyleSheet.words(
                TextMembers.look(of: values),
                placeholder: values[TextInputContract.placeholderColor].flatMap { GTKBrush.rgba($0.propValue) }))
        }
        if values.changed(TextAlignmentElementContract.horizontalTextAlignment) {
            view.setAlignment(values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
        }
        if values.changed(TextInputContract.cursorPosition) || values.changed(TextInputContract.selectionLength),
           let caret = values[TextInputContract.cursorPosition] {
            view.select(start: caret, length: values[TextInputContract.selectionLength] ?? 0)
        }
    }
}
