// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// A TextField: its words are `TextElementContract.text` and the change it reports is
    /// `InputViewContract.textChanged`. Each member reaches the field only where the tree changed it, which keeps
    /// the user's typing and caret their own.
    static func fields(_ registry: Registry<GTKView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = GTKTextFieldView()
            field.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies([
                TextElementContract.text, InputViewContract.placeholder, InputViewContract.maximumLength,
                VisualElementContract.isEnabled,
            ]) { view, values in
                if values.changed(InputViewContract.maximumLength) {
                    view.setMaximumLength(values[InputViewContract.maximumLength].flatMap { $0 > 0 ? $0 : nil })
                }
                if values.changed(TextElementContract.text) { view.setText(values[TextElementContract.text] ?? "") }
                if values.changed(InputViewContract.placeholder) {
                    view.setPlaceholder(values[InputViewContract.placeholder])
                }
                if values.changed(VisualElementContract.isEnabled) {
                    view.setEnabled(values[VisualElementContract.isEnabled] ?? true)
                }
            }
            field.raises(InputViewContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
    }
}
