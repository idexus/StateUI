// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A TextField, a TextEditor and a SearchField: their words are `TextualElementContract.text` and the change they
    /// report is `TextInputContract.textChanged`. Each member reaches the view only where the tree changed it,
    /// which keeps the user's typing and caret their own.
    static func fields(_ registry: Registry<UIView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = UIKitTextFieldView()
            hearInput(field, reports)
            field.typing.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies(inputMembers) { view, values in applyInput(view, values) }
            field.property(TextFieldContract.isPassword) { view, hidden in view.isSecureTextEntry = hidden ?? false }
            field.property(TextFieldContract.submitLabel) { view, key in
                view.setReturnKey(InputTraits.submitLabel(key, searching: false))
            }
            field.property(TextFieldContract.showsClearButton) { view, shows in
                view.clearButtonMode = shows == true ? .whileEditing : .never
            }
            field.raises(TextInputContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
        registry.add(TextEditorContract.self, create: { reports in
            let editor = UIKitTextEditorView()
            hearInput(editor, reports)
            return editor
        }, members: { editor in
            editor.applies(inputMembers) { view, values in applyInput(view, values) }
            editor.property(TextEditorContract.growsWithText) { view, grows in view.growsWithText = grows ?? false }
            editor.raises(TextInputContract.textChanged)
        })
        registry.add(SearchFieldContract.self, create: { reports in
            let search = UIKitSearchFieldView()
            hearInput(search, reports)
            search.typing.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(inputMembers) { view, values in applyInput(view, values) }
            search.property(SearchFieldContract.submitLabel) { view, key in
                view.setReturnKey(InputTraits.submitLabel(key, searching: true))
            }
            search.raises(TextInputContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    private static func hearInput<Realized: ElementContract>(_ view: any UIKitTextInputView, _ reports: Reports<Realized>) {
        view.typing.onTextChanged = { typed in
            reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
        }
    }

    /// What every view the user types in takes: its words in their case, their bound and what shows while they are none, whether
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

    private static func applyInput<Realized: ElementContract>(
        _ view: any UIKitTextInputView, _ values: ElementValues<Realized>
    ) {
        if values.changed(TextInputContract.maximumLength) {
            view.typing.maximumLength = values[TextInputContract.maximumLength].flatMap { $0 > 0 ? $0 : nil }
        }
        if values.changed(TextualElementContract.textCase) { view.typing.textCase = values[TextualElementContract.textCase] }
        if let words = TextMembers.words(values) { view.setText(words) }
        if values.changed(TextInputContract.placeholder) || values.changed(TextInputContract.placeholderColor) {
            view.setPlaceholder(
                values[TextInputContract.placeholder],
                color: values[TextInputContract.placeholderColor].flatMap { UIColor(stateUI: $0.propValue) })
        }
        if values.changed(VisualElementContract.isEnabled) || values.changed(TextInputContract.isReadOnly)
            || values.changed(TextInputContract.isSpellCheckEnabled)
            || values.changed(TextInputContract.isTextPredictionEnabled)
            || values.changed(TextInputContract.inputPurpose) {
            view.setBehaviour(
                enabled: values[VisualElementContract.isEnabled] ?? true,
                readOnly: values[TextInputContract.isReadOnly] ?? false,
                keyboard: UIKitKeyboard(InputTraits(values)))
        }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(TextAlignmentElementContract.horizontalTextAlignment) {
            view.setAlignment(values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
        }
        if values.changed(TextInputContract.cursorPosition) || values.changed(TextInputContract.selectionLength),
           let caret = values[TextInputContract.cursorPosition] {
            view.select(start: caret, length: values[TextInputContract.selectionLength] ?? 0)
        }
    }
}
#endif
