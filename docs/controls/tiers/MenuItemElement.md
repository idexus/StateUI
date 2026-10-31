<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItemElement

What every item a user chooses from says - a menu's entry, a toolbar's item, an action or a setting: a caption, a picture, whether it can be chosen, and the keys that choose it.

```swift
@State var saved = false

Text(saved ? "Saved" : "Draft")
    .toolbar {
        ToolbarButton("Save")
            .icon("save.png")
            .isEnabled(!saved)
            .onClicked { saved = true }
    }
```

Wears: [AutomationElement](AutomationElement.md)

Worn by: [MenuItem](../MenuItem.md) · [MenuToggle](../MenuToggle.md) · [ToolbarButton](../ToolbarButton.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/MenuItemElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `icon` | property | `ImageSource` | adaptive |
| `isEnabled` | property | `Bool` | native |
| `keyboardShortcut` | property | `KeyboardShortcut` | native |
| `text` | property | `String` | native |
