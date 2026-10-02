<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextElement

What every element showing words has: the words, and the case they are drawn in.

```swift
Button("Continue")
    .textCase(.uppercase)
```

Wears: [TextStyleElement](TextStyleElement.md)

Worn by: [Button](../Button.md) · [RadioButton](../RadioButton.md) · [SearchField](../SearchField.md) · [Span](../Span.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/TextElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `text` | property | `String` | native |
| `textCase` | property | `TextCase` | native |
