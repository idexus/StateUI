<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextAndIconElement

What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its picture.

```swift
@State var wordsShown = false

Button("Delete")
    .icon("trash.png")
    .showsText($wordsShown)
```

Worn by: [Button](../Button.md) · [ToolbarButton](../ToolbarButton.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/TextAndIconElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `showsText` | property | `Bool` | adaptive |
