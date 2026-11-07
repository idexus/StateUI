<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ClickElement

What a control the user chooses reports: a button, a link, a menu's entry, a toolbar's button.

```swift
@State var saved = false

Button(saved ? "Saved" : "Save")
    .onClicked { saved = true }
```

Worn by: [Button](../Button.md) · [Link](../Link.md) · [MenuItem](../MenuItem.md) · [ToolbarButton](../ToolbarButton.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/ClickElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onClicked` (`clicked`) | event |  | native |
