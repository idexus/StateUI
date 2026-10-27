<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# BarItemElement

What an item standing on a bar - a button, a setting or a group of them - shows of its own where its host draws the bar itself: the keyed style it wears, what its surface is made of, and the pointer over it its visual states follow. A host whose bar is the platform's keeps the platform's look.

```swift
Text("Inbox")
    .toolbar {
        ToolbarGroup {
            ToolbarButton("Archive")
            ToolbarButton("Move")
        }
        .background(.white)
        .shape(.roundedRectangle(12))
        .stroke(.gray)
        .visualState(.pointerOver) { $0.stroke(.cornflowerBlue) }
    }
```

Worn by: [ToolbarButton](../ToolbarButton.md) · [ToolbarGroup](../ToolbarGroup.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/BarItemElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `style` | property | `Name` | structure |
| `background` | property | `Material` | adaptive |
| `onPointerEntered` (`pointerEntered`) | event |  | native |
| `onPointerExited` (`pointerExited`) | event |  | native |
