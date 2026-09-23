<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextElement

What every element showing words has: the words, and the case they are drawn in.

Wears: [TextStyleElement](TextStyleElement.md)

Worn by: [Button](../Button.md) · [Label](../Label.md) · [RadioButton](../RadioButton.md) · [SearchField](../SearchField.md) · [Span](../Span.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md)

Declared in `lib/StateUI/Sources/Contracts/Mixins/TextElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `text` | property | `String` | native |
| `textCase` | property | `TextCase` | native |
