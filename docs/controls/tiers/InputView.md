<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# InputView

What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.

Wears: [View](View.md)

Worn by: [SearchField](../SearchField.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/InputViewContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `cursorPosition` | property | `Int` | native |
| `inputPurpose` | property | `InputPurpose` | adaptive |
| `isReadOnly` | property | `Bool` | native |
| `isSpellCheckEnabled` | property | `Bool` | native |
| `isTextPredictionEnabled` | property | `Bool` | native |
| `maximumLength` | property | `Int` | native |
| `placeholder` | property | `String` | native |
| `placeholderColor` | property | `Color` | native |
| `selectionLength` | property | `Int` | native |
| `onTextChanged` (`textChanged`) | event | `String` | native |
