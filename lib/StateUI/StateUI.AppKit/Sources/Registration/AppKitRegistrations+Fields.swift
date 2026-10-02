// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The fields a user types in. Their words are `TextualElementContract.text`
    /// and the change they report is `TextInputContract.textChanged` - two
    /// tiers, both worn. A text the host CARRIES IN is the host's to write, so
    /// the tree's words are not put over it; anything else the tree describes
    /// reaches the control only where the tree changed it, which is what keeps
    /// a user's typing and a user's caret their own.
    static func fields(_ registry: Registry<NSView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let entry = AppKitTextFieldView()
            entry.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            entry.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return entry
        }, members: { entry in
            entry.applies(Self.fieldMembers + [TextFieldContract.isPassword]) { view, values in
                let words = Self.words(values)
                view.textCase = values[TextualElementContract.textCase]

                view.apply(
                    text: words,
                    writeText: (values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase))
                        && words != nil,
                    placeholder: values[TextInputContract.placeholder],
                    placeholderColor: values[TextInputContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[TextInputContract.isReadOnly] ?? false,
                    secure: values[TextFieldContract.isPassword] ?? false,
                    maximumLength: values[TextInputContract.maximumLength],
                    traits: InputTraits(values),
                    cursorPosition: values[TextInputContract.cursorPosition],
                    selectionLength: values[TextInputContract.selectionLength],
                    writeSelection: Self.writesSelection(values))
            }
            entry.raises(TextInputContract.textChanged)
            entry.raises(TextFieldContract.submitted)
        })

        registry.add(TextEditorContract.self, create: { reports in
            let editor = AppKitTextEditorView()
            editor.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            return editor
        }, members: { editor in
            editor.applies(Self.fieldMembers + [TextEditorContract.growsWithText]) { view, values in
                let words = Self.words(values)
                view.textCase = values[TextualElementContract.textCase]

                view.apply(
                    text: words,
                    writeText: (values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase))
                        && words != nil,
                    placeholder: values[TextInputContract.placeholder],
                    placeholderColor: values[TextInputContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[TextInputContract.isReadOnly] ?? false,
                    maximumLength: values[TextInputContract.maximumLength],
                    traits: InputTraits(values),
                    cursorPosition: values[TextInputContract.cursorPosition],
                    selectionLength: values[TextInputContract.selectionLength],
                    writeSelection: Self.writesSelection(values),
                    growsWithText: values[TextEditorContract.growsWithText] == true)
            }
            editor.raises(TextInputContract.textChanged)
        })

        registry.add(SearchFieldContract.self, create: { reports in
            let search = AppKitSearchFieldView()
            search.onTextChanged = { typed in
                reports.report(TextualElementContract.text, typed, as: TextInputContract.textChanged)
            }
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(Self.fieldMembers) { view, values in
                let words = Self.words(values)
                view.textCase = values[TextualElementContract.textCase]

                view.apply(
                    text: words,
                    writeText: (values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase))
                        && words != nil,
                    placeholder: values[TextInputContract.placeholder],
                    placeholderColor: values[TextInputContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[TextInputContract.isReadOnly] ?? false,
                    maximumLength: values[TextInputContract.maximumLength],
                    traits: InputTraits(values),
                    cursorPosition: values[TextInputContract.cursorPosition],
                    selectionLength: values[TextInputContract.selectionLength],
                    writeSelection: Self.writesSelection(values))
            }
            search.raises(TextInputContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    /// What every field takes, whatever kind of field it is.
    private static let fieldMembers: [any ContractMember] = [
        TextualElementContract.text, TextualElementContract.textCase, TextInputContract.placeholder,
        TextInputContract.placeholderColor,
        TextStyleElementContract.textColor, VisualElementContract.background,
        FontElementContract.fontFamily, FontElementContract.fontSize, FontElementContract.fontAttributes,
        TextAlignmentElementContract.horizontalTextAlignment, VisualElementContract.isEnabled,
        TextInputContract.isReadOnly, TextInputContract.maximumLength,
        TextInputContract.isSpellCheckEnabled, TextInputContract.isTextPredictionEnabled, TextInputContract.inputPurpose,
        TextInputContract.cursorPosition, TextInputContract.selectionLength,
    ]

    /// The caret moves only where the tree moved it, never because something
    /// else about the field changed.
    private static func writesSelection<Realized: ElementContract>(
        _ values: ElementValues<Realized>
    ) -> Bool {
        values.changed(TextInputContract.cursorPosition) || values.changed(TextInputContract.selectionLength)
    }
}

#endif
