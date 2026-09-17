// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every field a reader types into has: the text's limits and caret, the
/// keyboard it asks for, and the placeholder shown while it is empty.
public enum InputViewContract: Contract {
    /// The tier's name.
    public static let name = "InputView"

    /// A field is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Where the caret is, in characters from the start.
    public static let cursorPosition = ElementProperty<Self, Int>(
        "cursorPosition", layer: .native, travels: false)

    /// What the text is for, which picks the on-screen keyboard.
    public static let inputPurpose = ElementProperty<Self, InputPurpose>("inputPurpose", layer: .adaptive)

    /// Whether the text can be selected and copied but not changed.
    public static let isReadOnly = ElementProperty<Self, Bool>("isReadOnly", layer: .native)

    /// Whether the platform's spellcheck marks the text.
    public static let isSpellCheckEnabled = ElementProperty<Self, Bool>("isSpellCheckEnabled", layer: .native)

    /// Whether the platform suggests the next word.
    public static let isTextPredictionEnabled = ElementProperty<Self, Bool>(
        "isTextPredictionEnabled", layer: .native)

    /// The most characters the field holds.
    public static let maximumLength = ElementProperty<Self, Int>(
        "maximumLength", layer: .native, travels: false)

    /// What the field shows while it is empty.
    public static let placeholder = ElementProperty<Self, String>("placeholder", layer: .native)

    /// The placeholder's colour.
    public static let placeholderColor = ElementProperty<Self, Color>("placeholderColor", layer: .native)

    /// How many characters are selected from the caret.
    public static let selectionLength = ElementProperty<Self, Int>(
        "selectionLength", layer: .native, travels: false)

    /// The reader changed the text, with the text it now holds.
    public static let textChanged = ElementEvent<Self, String>("textChanged", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        cursorPosition, inputPurpose, isReadOnly, isSpellCheckEnabled, isTextPredictionEnabled,
        maximumLength, placeholder, placeholderColor, selectionLength, textChanged,
    ]
}
