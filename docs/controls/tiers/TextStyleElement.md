<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextStyleElement

How text looks wherever it is drawn: its colour and the space between its letters.

```swift
Text("Overdue")
    .textColor(.firebrick)
    .tracking(1.5)
```

Wears: [PropertyContainer](PropertyContainer.md)

Worn by: [Button](../Button.md) · [DatePicker](../DatePicker.md) · [Picker](../Picker.md) · [RadioButton](../RadioButton.md) · [SearchField](../SearchField.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TextSpan](../TextSpan.md) · [TimePicker](../TimePicker.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/TextStyleElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `tracking` | property | `Double` | native |
| `textColor` | property | `Color` | native |
