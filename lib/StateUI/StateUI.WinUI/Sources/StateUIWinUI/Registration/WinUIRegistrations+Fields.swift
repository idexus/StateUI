// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A TextField, a TextEditor and a SearchField: their words are `TextElementContract.text` and the change they
    /// report is `TextInputContract.textChanged`. Their words and caret reach the view only where the tree changed
    /// them, which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<WinUIView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = WinUITextFieldView()
            hearInput(field, reports)
            field.onSubmitted = { reports.raise(SubmitElementContract.submitted) }
            return field
        }, members: { field in
            field.property(TextFieldContract.isPassword) { view, password in view.setPassword(password ?? false) }
            field.applies(wordMembers) { view, values in applyWords(view, values) }
            field.applies(boxMembers) { view, values in applyBox(view, values) }
            field.applies(outlineMembers) { view, values in applyOutline(view, values) }
            field.declares(TextInputContract.textChanged)
            field.declares(SubmitElementContract.submitted)
        })
        registry.add(TextEditorContract.self, create: { reports in
            let editor = WinUITextEditorView()
            hearInput(editor, reports)
            return editor
        }, members: { editor in
            editor.applies(wordMembers) { view, values in applyWords(view, values) }
            editor.applies(boxMembers) { view, values in applyBox(view, values) }
            editor.applies(outlineMembers) { view, values in applyOutline(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.growsWithText = grows ?? false }
            editor.declares(TextInputContract.textChanged)
        })
        registry.add(SearchFieldContract.self, create: { reports in
            let search = WinUISearchFieldView()
            hearInput(search, reports)
            search.onSubmitted = { reports.raise(SubmitElementContract.submitted) }
            return search
        }, members: { search in
            search.applies(wordMembers) { view, values in applyWords(view, values) }
            search.applies(outlineMembers) { view, values in applyOutline(view, values) }
            search.property(TextInputContract.isReadOnly) { view, readOnly in view.setReadOnly(readOnly ?? false) }
            search.property(TextAlignmentElementContract.horizontalTextAlignment) { view, alignment in
                view.setAlignment(alignment ?? .start)
            }
            search.property(TextInputContract.placeholderColor) { view, color in view.setPlaceholderColor(color?.propValue) }
            search.applies(
                TextInputContract.isSpellCheckEnabled, TextInputContract.isTextPredictionEnabled,
                TextInputContract.inputPurpose) { view, values in view.setTraits(InputTraits(values)) }
            search.declares(TextInputContract.textChanged)
            search.declares(SubmitElementContract.submitted)
        })
    }

    /// A field's outline and the shape its corners take.
    private static let outlineMembers = PropertyList(
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape)

    private static func applyOutline<Realized: ElementContract>(_ view: WinUITextInputView, _ values: ElementValues<Realized>) {
        view.setOutline(
            stroke: values[BorderElementContract.stroke]?.propValue, lineWidth: values[BorderElementContract.lineWidth],
            shape: values[BorderElementContract.shape]?.propValue)
    }

    private static func hearInput<Realized: ElementContract>(_ view: WinUITextInputView, _ reports: ControlReports<Realized>) {
        view.onTextChanged = { typed in reports.report(TextElementContract.text, typed, as: TextInputContract.textChanged) }
    }

    /// What every view the user types in takes: its words and their case, what it shows while they are none, how
    /// many it holds, whether it takes them, and their font and color.
    private static let wordMembers = PropertyList(
        TextElementContract.text, TextualElementContract.textCase, PlaceholderElementContract.placeholder,
        TextInputContract.maximumLength, EnabledElementContract.isEnabled)
        + TextMembers.lookMembers

    private static func applyWords<Realized: ElementContract>(_ view: WinUITextInputView, _ values: ElementValues<Realized>) {
        view.maximumLength = values[TextInputContract.maximumLength].flatMap { $0 > 0 ? $0 : nil }
        let textCase = values[TextualElementContract.textCase] ?? .none
        if values.changed(TextualElementContract.textCase) { view.setCasing(textCase) }
        if values.changed(TextElementContract.text) || values.changed(TextualElementContract.textCase) {
            view.setText(textCase.applied(to: values[TextElementContract.text] ?? ""))
        }
        if values.changed(PlaceholderElementContract.placeholder) { view.setPlaceholder(values[PlaceholderElementContract.placeholder]) }
        if values.changed(EnabledElementContract.isEnabled) {
            view.setEnabled(values[EnabledElementContract.isEnabled] ?? true)
        }
        if let look = TextMembers.look(values) { view.setLook(look) }
    }

    /// What a text box takes beyond: how it takes words, its words across it, its placeholder's color, and the
    /// caret and the selection.
    private static let boxMembers = PropertyList(
        TextInputContract.isReadOnly, TextInputContract.isSpellCheckEnabled, TextInputContract.isTextPredictionEnabled,
        TextInputContract.inputPurpose, TextAlignmentElementContract.horizontalTextAlignment,
        TextInputContract.placeholderColor, TextInputContract.cursorPosition, TextInputContract.selectionLength)

    private static func applyBox<Realized: ElementContract>(_ view: WinUITextInputView, _ values: ElementValues<Realized>) {
        view.setBehavior(readOnly: values[TextInputContract.isReadOnly] ?? false, traits: InputTraits(values))
        view.setLook(
            alignment: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
            placeholderColor: values[TextInputContract.placeholderColor]?.propValue)
        if values.changed(TextInputContract.cursorPosition) || values.changed(TextInputContract.selectionLength),
           let caret = values[TextInputContract.cursorPosition] {
            view.select(start: caret, length: values[TextInputContract.selectionLength] ?? 0)
        }
    }
}
