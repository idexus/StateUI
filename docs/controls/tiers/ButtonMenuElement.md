<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ButtonMenuElement

What a button that holds a menu has - a button's, a toolbar button's: how its menu opens, and whether the arrow saying so shows.

```swift
@State var sorted = "By name"

Text(sorted)
    .toolbar {
        ToolbarButton("Sort")
            .icon("sort.png")
            .menu {
                MenuItem("By name").onClicked { sorted = "By name" }
                MenuItem("By date").onClicked { sorted = "By date" }
            }
    }
```

Worn by: [Button](../Button.md) · [ToolbarButton](../ToolbarButton.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/ButtonMenuElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `menuKind` | property | `ButtonMenuKind` | adaptive |
| `showsMenuArrow` | property | `Bool` | native |
