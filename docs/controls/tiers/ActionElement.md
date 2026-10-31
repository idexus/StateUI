<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ActionElement

What an item that acts has - a menu's entry, a toolbar's button: what choosing it does, and how the platform marks it.

```swift
@State var deleted = false

Text(deleted ? "Deleted" : "Report.pdf")
    .contextMenu {
        MenuItem("Delete")
            .role(.destructive)
            .onClicked { deleted = true }
    }
```

Wears: [AutomationElement](AutomationElement.md)

Worn by: [MenuItem](../MenuItem.md) · [ToolbarButton](../ToolbarButton.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/ActionElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onClicked` (`clicked`) | event |  | native |
| `role` | property | `ActionRole` | adaptive |
