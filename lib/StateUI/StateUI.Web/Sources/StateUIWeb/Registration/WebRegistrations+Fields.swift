// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A TextField, a SearchField and a TextEditor: their words are `TextElementContract.text` and the change they
    /// report is `TextInputContract.textChanged`. Each member reaches the view only where the tree changed it, which
    /// keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<WebDOMView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = WebTextInputView(.field)
            hearInput(field, reports)
            field.onSubmitted = { reports.raise(SubmitElementContract.submitted) }
            return field
        }, members: { field in
            field.applies(inputMembers) { view, values in applyInput(view, values) }
            field.applies(outlineMembers) { view, values in applyOutline(view, values) }
            field.property(TextFieldContract.isPassword) { view, hidden in view.setPassword(hidden ?? false) }
            field.property(SubmitElementContract.submitLabel) { view, label in
                view.setSubmitLabel(InputTraits.submitLabel(label, searching: false))
            }
            field.declares(TextInputContract.textChanged)
            field.declares(SubmitElementContract.submitted)
        })
        registry.add(SearchFieldContract.self, create: { reports in
            let search = WebTextInputView(.search)
            hearInput(search, reports)
            search.onSubmitted = { reports.raise(SubmitElementContract.submitted) }
            search.setSubmitLabel(InputTraits.submitLabel(nil, searching: true))
            return search
        }, members: { search in
            search.applies(inputMembers) { view, values in applyInput(view, values) }
            search.applies(outlineMembers) { view, values in applyOutline(view, values) }
            search.property(SubmitElementContract.submitLabel) { view, label in
                view.setSubmitLabel(InputTraits.submitLabel(label, searching: true))
            }
            search.declares(TextInputContract.textChanged)
            search.declares(SubmitElementContract.submitted)
        })
        registry.add(TextEditorContract.self, create: { reports in
            let editor = WebTextInputView(.editor)
            hearInput(editor, reports)
            return editor
        }, members: { editor in
            editor.applies(inputMembers) { view, values in applyInput(view, values) }
            editor.applies(outlineMembers) { view, values in applyOutline(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.setGrowsWithText(grows ?? false) }
            editor.declares(TextInputContract.textChanged)
        })
    }

    /// A field's outline and the shape its ground and outline follow.
    private static let outlineMembers = PropertyList(
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape)

    private static func applyOutline<Realized: ElementContract>(_ view: WebTextInputView, _ values: ElementValues<Realized>) {
        view.setOutline(
            stroke: values[BorderElementContract.stroke]?.propValue, lineWidth: values[BorderElementContract.lineWidth],
            shape: values[BorderElementContract.shape]?.propValue)
    }

    private static func hearInput<Realized: ElementContract>(_ view: WebTextInputView, _ reports: ControlReports<Realized>) {
        view.onTextChanged = { typed in reports.report(TextElementContract.text, typed, as: TextInputContract.textChanged) }
    }

    /// What every view the user types in takes: its words, their bound and what shows while they are none, whether
    /// and how it takes them, their look and where they stand, and the caret and the selection.
    private static let inputMembers = PropertyList(
        TextElementContract.text, TextualElementContract.textCase, PlaceholderElementContract.placeholder,
        TextInputContract.maximumLength, EnabledElementContract.isEnabled, TextInputContract.isReadOnly,
        TextInputContract.isSpellCheckEnabled, TextInputContract.isTextPredictionEnabled,
        TextInputContract.inputPurpose)
        + TextMembers.lookMembers
        + PropertyList(
            TextInputContract.placeholderColor, TextAlignmentElementContract.horizontalTextAlignment,
            TextInputContract.cursorPosition, TextInputContract.selectionLength)

    private static func applyInput<Realized: ElementContract>(_ view: WebTextInputView, _ values: ElementValues<Realized>) {
        if values.changed(TextInputContract.maximumLength) {
            view.setMaximumLength(values[TextInputContract.maximumLength].flatMap { $0 > 0 ? $0 : nil })
        }
        if values.changed(TextualElementContract.textCase) { view.textCase = values[TextualElementContract.textCase] }
        if values.changed(TextElementContract.text) || values.changed(TextualElementContract.textCase) {
            let textCase = values[TextualElementContract.textCase] ?? .none
            view.setText(textCase.applied(to: values[TextElementContract.text] ?? ""))
        }
        if values.changed(PlaceholderElementContract.placeholder) { view.setPlaceholder(values[PlaceholderElementContract.placeholder]) }
        if values.changed(EnabledElementContract.isEnabled) {
            view.setEnabled(values[EnabledElementContract.isEnabled] ?? true)
        }
        if values.changed(TextInputContract.isReadOnly) {
            view.setReadOnly(values[TextInputContract.isReadOnly] ?? false)
        }
        if let traits = InputTraits.changed(values) { view.setTraits(traits) }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(TextInputContract.placeholderColor) {
            view.setPlaceholderColor(values[TextInputContract.placeholderColor]?.propValue)
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
