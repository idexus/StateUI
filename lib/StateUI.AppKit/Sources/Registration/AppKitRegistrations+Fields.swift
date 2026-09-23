// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

extension AppKitRegistrations {
    /// The fields a user types in. Their words are `TextElementContract.text`
    /// and the change they report is `InputViewContract.textChanged` - two
    /// tiers, both worn. A text the host CARRIES IN is the host's to write, so
    /// the tree's words are not put over it; anything else the tree describes
    /// reaches the control only where the tree changed it, which is what keeps
    /// a user's typing and a user's caret their own.
    static func fields(_ registry: Registry<NSView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let entry = AppKitTextFieldView()
            entry.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            entry.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return entry
        }, members: { entry in
            entry.applies(Self.fieldMembers + [TextFieldContract.isPassword]) { view, values in
                let words = Self.words(values)

                view.apply(
                    text: words,
                    writeText: values.changed(TextElementContract.text) && words != nil,
                    placeholder: values[InputViewContract.placeholder],
                    placeholderColor: values[InputViewContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[InputViewContract.isReadOnly] ?? false,
                    secure: values[TextFieldContract.isPassword] ?? false,
                    maximumLength: values[InputViewContract.maximumLength],
                    spellChecking: values[InputViewContract.isSpellCheckEnabled] ?? true,
                    textPrediction: values[InputViewContract.isTextPredictionEnabled] ?? true,
                    cursorPosition: values[InputViewContract.cursorPosition],
                    selectionLength: values[InputViewContract.selectionLength],
                    writeSelection: Self.writesSelection(values))
            }
            entry.raises(InputViewContract.textChanged)
            entry.raises(TextFieldContract.submitted)
        })

        registry.add(TextEditorContract.self, create: { reports in
            let editor = AppKitTextEditorView()
            editor.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            return editor
        }, members: { editor in
            editor.applies(Self.fieldMembers + [TextEditorContract.growsWithText]) { view, values in
                let words = Self.words(values)

                view.apply(
                    text: words,
                    writeText: values.changed(TextElementContract.text) && words != nil,
                    placeholder: values[InputViewContract.placeholder],
                    placeholderColor: values[InputViewContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[InputViewContract.isReadOnly] ?? false,
                    maximumLength: values[InputViewContract.maximumLength],
                    spellChecking: values[InputViewContract.isSpellCheckEnabled] ?? true,
                    textPrediction: values[InputViewContract.isTextPredictionEnabled] ?? true,
                    cursorPosition: values[InputViewContract.cursorPosition],
                    selectionLength: values[InputViewContract.selectionLength],
                    writeSelection: Self.writesSelection(values),
                    growsWithText: values[TextEditorContract.growsWithText] == true)
            }
            editor.raises(InputViewContract.textChanged)
        })

        registry.add(SearchFieldContract.self, create: { reports in
            let search = AppKitSearchFieldView()
            search.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(Self.fieldMembers) { view, values in
                let words = Self.words(values)

                view.apply(
                    text: words,
                    writeText: values.changed(TextElementContract.text) && words != nil,
                    placeholder: values[InputViewContract.placeholder],
                    placeholderColor: values[InputViewContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[InputViewContract.isReadOnly] ?? false,
                    maximumLength: values[InputViewContract.maximumLength],
                    spellChecking: values[InputViewContract.isSpellCheckEnabled] ?? true,
                    textPrediction: values[InputViewContract.isTextPredictionEnabled] ?? true,
                    cursorPosition: values[InputViewContract.cursorPosition],
                    selectionLength: values[InputViewContract.selectionLength],
                    writeSelection: Self.writesSelection(values))
            }
            search.raises(InputViewContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    /// What every field takes, whatever kind of field it is.
    private static let fieldMembers: [any ContractMember] = [
        TextElementContract.text, InputViewContract.placeholder, InputViewContract.placeholderColor,
        TextStyleElementContract.textColor, VisualElementContract.background,
        FontElementContract.fontFamily, FontElementContract.fontSize, FontElementContract.fontAttributes,
        TextAlignmentElementContract.horizontalTextAlignment, VisualElementContract.isEnabled,
        InputViewContract.isReadOnly, InputViewContract.maximumLength,
        InputViewContract.isSpellCheckEnabled, InputViewContract.isTextPredictionEnabled,
        InputViewContract.cursorPosition, InputViewContract.selectionLength,
    ]

    /// The caret moves only where the tree moved it, never because something
    /// else about the field changed.
    private static func writesSelection<Realized: ElementContract>(
        _ values: ElementValues<Realized>
    ) -> Bool {
        values.changed(InputViewContract.cursorPosition) || values.changed(InputViewContract.selectionLength)
    }
}

#endif
