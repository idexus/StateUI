// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A TextField, a SearchField and a TextEditor: their words are `TextElementContract.text` and the change
    /// they report is `InputViewContract.textChanged`. Each member reaches the field only where the tree
    /// changed it, which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<AndroidView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = AndroidTextFieldView(.field)
            field.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(inputMembers + [TextFieldContract.isPassword]) { view, values in applyField(view, values) }
            field.property(TextFieldContract.returnKey) { view, key in view.setReturnKey(key) }
            field.raises(InputViewContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })

        registry.add(SearchFieldContract.self, create: { reports in
            let search = AndroidTextFieldView(.search)
            search.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(inputMembers) { view, values in applyField(view, values) }
            search.property(SearchFieldContract.returnKey) { view, key in view.setReturnKey(key) }
            search.raises(InputViewContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })

        registry.add(TextEditorContract.self, create: { reports in
            let editor = AndroidTextFieldView(.editor)
            editor.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            return editor
        }, members: { editor in
            editor.applies(inputMembers) { view, values in applyField(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.setGrows(grows ?? false) }
            editor.raises(InputViewContract.textChanged)
        })
    }

    /// What every field takes whole.
    private static let inputMembers: [any ContractMember] = [
        TextElementContract.text, TextElementContract.textCase, FontElementContract.fontSize,
        FontElementContract.fontAttributes,
        FontElementContract.fontFamily, TextStyleElementContract.textColor, InputViewContract.placeholder,
        InputViewContract.placeholderColor, TextAlignmentElementContract.horizontalTextAlignment,
        InputViewContract.inputPurpose, InputViewContract.isTextPredictionEnabled,
        InputViewContract.maximumLength, InputViewContract.cursorPosition, InputViewContract.selectionLength,
        InputViewContract.isReadOnly, VisualElementContract.isEnabled,
    ]

    private static func applyField<Realized: ElementContract>(
        _ view: AndroidTextFieldView, _ values: ElementValues<Realized>
    ) {
        if values.changed(TextFieldContract.isPassword) {
            view.setPassword(values[TextFieldContract.isPassword] ?? false)
        }
        if values.changed(TextElementContract.textCase) { view.textCase = values[TextElementContract.textCase] }
        if values.changed(TextElementContract.text) || values.changed(TextElementContract.textCase),
           let words = words(values) {
            view.setText(words)
        }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(InputViewContract.placeholder) {
            view.setPlaceholder(values[InputViewContract.placeholder])
        }
        if values.changed(InputViewContract.placeholderColor) {
            view.setPlaceholderColor(values[InputViewContract.placeholderColor]?.propValue)
        }
        if values.changed(InputViewContract.inputPurpose) || values.changed(InputViewContract.isTextPredictionEnabled) {
            view.setTraits(InputTraits(
                spellChecked: true, predicted: values[InputViewContract.isTextPredictionEnabled] ?? true,
                purpose: values[InputViewContract.inputPurpose]))
        }
        if values.changed(TextAlignmentElementContract.horizontalTextAlignment) {
            view.setAlignment(values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
        }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        if values.changed(InputViewContract.isReadOnly) { view.setReadOnly(values[InputViewContract.isReadOnly] ?? false) }
        view.maximumLength = values[InputViewContract.maximumLength].map { max(0, $0) }

        if values.changed(InputViewContract.cursorPosition) || values.changed(InputViewContract.selectionLength) {
            view.select(
                from: values[InputViewContract.cursorPosition] ?? 0,
                length: values[InputViewContract.selectionLength] ?? 0)
        }
    }

    /// The words to put on a field, in their case: none where the host carries them in, since the field is their
    /// source.
    private static func words<Realized: ElementContract>(_ values: ElementValues<Realized>) -> String? {
        guard !values.carriedIn(TextElementContract.text) else { return nil }
        return (values[TextElementContract.textCase] ?? .none).applied(to: values[TextElementContract.text] ?? "")
    }
}
