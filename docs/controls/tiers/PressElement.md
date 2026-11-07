<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PressElement

What a control held down and let go of reports: a button, a slider, a bar's button.

```swift
Text("Inbox")
    .toolbar {
        ToolbarButton("Sign out")
            .shape(.roundedRectangle(12))
            .visualState(.pressed) { $0.background(.lightGray) }
    }
```

Worn by: [Button](../Button.md) · [Slider](../Slider.md) · [ToolbarButton](../ToolbarButton.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/PressElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onPressed` (`pressed`) | event |  | native |
| `onReleased` (`released`) | event |  | native |
