<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ShortcutElement

The keys that choose an element from the keyboard while its window is in front: a button, a menu's or a toolbar's item.

```swift
Button("Save")
    .keyboardShortcut("s")
    .onClicked { print("saved") }
```

Worn by: [Button](../Button.md) · [MenuItem](../MenuItem.md) · [MenuToggle](../MenuToggle.md) · [ToolbarButton](../ToolbarButton.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/ShortcutElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `keyboardShortcut` | property | `KeyboardShortcut` | native |
