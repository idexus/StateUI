<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextualElement

What every element drawing its words itself has: the case they are drawn in, their color, and the words.

```swift
Button("Continue")
    .textCase(.uppercase)
```

Wears: [TextColorElement](TextColorElement.md) · [TextElement](TextElement.md)

Worn by: [Button](../Button.md) · [CheckBox](../CheckBox.md) · [Link](../Link.md) · [SearchField](../SearchField.md) · [Switch](../Switch.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TextSpan](../TextSpan.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/TextualElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `textCase` | property | `TextCase` | native |
