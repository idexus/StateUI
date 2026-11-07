<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToggleElement

What a control turned on and off holds and reports: a check box, a switch, a menu's and a toolbar's toggle.

```swift
@State var wifi = true

Switch("Wi-Fi", isOn: $wifi)
    .onToggled { on in print("Wi-Fi \(on)") }
```

Worn by: [CheckBox](../CheckBox.md) · [MenuToggle](../MenuToggle.md) · [Switch](../Switch.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/ToggleElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `isOn` | property | `Bool` | native |
| `onToggled` (`toggled`) | event | `Bool` | native |
