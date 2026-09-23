// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// A TextField: its words are `TextElementContract.text` and the change it reports is
    /// `InputViewContract.textChanged`. Each member reaches the field only where the tree changed
    /// it, which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<AndroidView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = AndroidTextFieldView()
            field.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(fieldMembers) { view, values in applyField(view, values) }
            field.raises(InputViewContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
    }

    /// What a field takes whole.
    private static let fieldMembers: [any ContractMember] = [
        TextElementContract.text, FontElementContract.fontSize, FontElementContract.fontAttributes,
        TextStyleElementContract.textColor, InputViewContract.placeholder, InputViewContract.placeholderColor,
        InputViewContract.maximumLength, InputViewContract.cursorPosition, InputViewContract.selectionLength,
        TextFieldContract.isPassword, VisualElementContract.isEnabled,
    ]

    private static func applyField<Realized: ElementContract>(
        _ view: AndroidTextFieldView, _ values: ElementValues<Realized>
    ) {
        if values.changed(TextFieldContract.isPassword) {
            view.setPassword(values[TextFieldContract.isPassword] ?? false)
        }
        if values.changed(TextElementContract.text), let words = words(values) {
            view.setText(words)
        }
        if values.changed(FontElementContract.fontSize) {
            view.setFontSize(values[FontElementContract.fontSize])
        }
        if values.changed(FontElementContract.fontAttributes) {
            view.setFontAttributes(values[FontElementContract.fontAttributes])
        }
        if values.changed(TextStyleElementContract.textColor) {
            view.setTextColor(values[TextStyleElementContract.textColor]?.propValue)
        }
        if values.changed(InputViewContract.placeholder) {
            view.setPlaceholder(values[InputViewContract.placeholder])
        }
        if values.changed(InputViewContract.placeholderColor) {
            view.setPlaceholderColor(values[InputViewContract.placeholderColor]?.propValue)
        }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        view.maximumLength = values[InputViewContract.maximumLength].map { max(0, $0) }

        if values.changed(InputViewContract.cursorPosition) || values.changed(InputViewContract.selectionLength) {
            view.select(
                from: values[InputViewContract.cursorPosition] ?? 0,
                length: values[InputViewContract.selectionLength] ?? 0)
        }
    }

    /// The words to put on a field: none where the host carries them in, since the field is their source.
    private static func words<Realized: ElementContract>(_ values: ElementValues<Realized>) -> String? {
        values.carriedIn(TextElementContract.text) ? nil : (values[TextElementContract.text] ?? "")
    }
}
