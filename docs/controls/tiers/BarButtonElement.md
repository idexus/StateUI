<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# BarButtonElement

A button on a bar - an action or a setting: the press its visual states follow, beside the pointer over it every item on a bar reports.

```swift
Text("Inbox")
    .toolbar {
        ToolbarButton("Sign out")
            .shape(.roundedRectangle(12))
            .visualState(.pressed) { $0.background(.lightGray) }
    }
```

Wears: [BarItemElement](BarItemElement.md)

Worn by: [ToolbarButton](../ToolbarButton.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/BarButtonElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onPressed` (`pressed`) | event |  | native |
| `onReleased` (`released`) | event |  | native |
