// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A TextField: its words are `TextualElementContract.text` and the change it reports is
    /// `TextInputContract.textChanged`. Each member reaches the field only where the tree changed it, which keeps the
    /// user's typing and caret their own.
    static func fields(_ registry: Registry<WebDOMView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = WebTextFieldView()
            field.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(inputMembers) { view, values in applyInput(view, values) }
            field.property(TextFieldContract.isPassword) { view, hidden in view.setPassword(hidden ?? false) }
            field.raises(TextInputContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
    }

    /// What the field takes: its words, their bound and what shows while they are none, whether it takes them, and
    /// their look.
    private static let inputMembers: [any ContractMember] = [
        TextualElementContract.text, TextualElementContract.textCase, TextInputContract.placeholder,
        TextInputContract.maximumLength, VisualElementContract.isEnabled, TextInputContract.isReadOnly,
        FontElementContract.fontSize, FontElementContract.fontAttributes, FontElementContract.fontFamily,
        TextStyleElementContract.textColor,
    ]

    private static func applyInput<Realized: ElementContract>(_ view: WebTextFieldView, _ values: ElementValues<Realized>) {
        if values.changed(TextInputContract.maximumLength) {
            view.setMaximumLength(values[TextInputContract.maximumLength].flatMap { $0 > 0 ? $0 : nil })
        }
        if values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase) {
            let textCase = values[TextualElementContract.textCase] ?? .none
            view.setText(textCase.applied(to: values[TextualElementContract.text] ?? ""))
        }
        if values.changed(TextInputContract.placeholder) { view.setPlaceholder(values[TextInputContract.placeholder]) }
        if values.changed(VisualElementContract.isEnabled) {
            view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
        }
        if values.changed(TextInputContract.isReadOnly) {
            view.setReadOnly(values[TextInputContract.isReadOnly] ?? false)
        }
        if let look = TextMembers.look(values) { view.setLook(look) }
    }
}
