// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A TextField, a SearchField and a TextEditor: their words are `TextualElementContract.text` and the change
    /// they report is `TextInputContract.textChanged`. Each member reaches the field only where the tree
    /// changed it, which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<AndroidView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = AndroidTextFieldView(.field)
            field.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(inputMembers + [TextFieldContract.isPassword]) { view, values in applyField(view, values) }
            field.property(TextFieldContract.submitLabel) { view, key in view.setReturnKey(key) }
            field.raises(TextInputContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })

        registry.add(SearchFieldContract.self, create: { reports in
            let search = AndroidTextFieldView(.search)
            search.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(inputMembers) { view, values in applyField(view, values) }
            search.property(SearchFieldContract.submitLabel) { view, key in view.setReturnKey(key) }
            search.raises(TextInputContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })

        registry.add(TextEditorContract.self, create: { reports in
            let editor = AndroidTextFieldView(.editor)
            editor.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            return editor
        }, members: { editor in
            editor.applies(inputMembers) { view, values in applyField(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.setGrows(grows ?? false) }
            editor.raises(TextInputContract.textChanged)
        })
    }

    /// What every field takes whole.
    private static let inputMembers: [any ContractMember] = [
        TextualElementContract.text, TextualElementContract.textCase, FontElementContract.fontSize,
        FontElementContract.fontAttributes,
        FontElementContract.fontFamily, TextStyleElementContract.textColor, TextInputContract.placeholder,
        TextInputContract.placeholderColor, TextAlignmentElementContract.horizontalTextAlignment,
        TextInputContract.inputPurpose, TextInputContract.isTextPredictionEnabled,
        TextInputContract.maximumLength, TextInputContract.cursorPosition, TextInputContract.selectionLength,
        TextInputContract.isReadOnly, VisualElementContract.isEnabled,
    ]

    private static func applyField<Realized: ElementContract>(
        _ view: AndroidTextFieldView, _ values: ElementValues<Realized>
    ) {
        if values.changed(TextFieldContract.isPassword) {
            view.setPassword(values[TextFieldContract.isPassword] ?? false)
        }
        if values.changed(TextualElementContract.textCase) { view.textCase = values[TextualElementContract.textCase] }
        if values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase),
           let words = words(values) {
            view.setText(words)
        }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(TextInputContract.placeholder) {
            view.setPlaceholder(values[TextInputContract.placeholder])
        }
        if values.changed(TextInputContract.placeholderColor) {
            view.setPlaceholderColor(values[TextInputContract.placeholderColor]?.propValue)
        }
        if values.changed(TextInputContract.inputPurpose) || values.changed(TextInputContract.isTextPredictionEnabled) {
            view.setTraits(InputTraits(
                spellChecked: true, predicted: values[TextInputContract.isTextPredictionEnabled] ?? true,
                purpose: values[TextInputContract.inputPurpose]))
        }
        if values.changed(TextAlignmentElementContract.horizontalTextAlignment) {
            view.setAlignment(values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
        }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        if values.changed(TextInputContract.isReadOnly) { view.setReadOnly(values[TextInputContract.isReadOnly] ?? false) }
        view.maximumLength = values[TextInputContract.maximumLength].map { max(0, $0) }

        if values.changed(TextInputContract.cursorPosition) || values.changed(TextInputContract.selectionLength) {
            view.select(
                from: values[TextInputContract.cursorPosition] ?? 0,
                length: values[TextInputContract.selectionLength] ?? 0)
        }
    }

    /// The words to put on a field, in their case: none where the host carries them in, since the field is their
    /// source.
    private static func words<Realized: ElementContract>(_ values: ElementValues<Realized>) -> String? {
        guard !values.carriedIn(TextualElementContract.text) else { return nil }
        return (values[TextualElementContract.textCase] ?? .none).applied(to: values[TextualElementContract.text] ?? "")
    }
}
