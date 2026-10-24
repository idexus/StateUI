<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# FocusElement

An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.

```swift
@State var editing = false

TextField("Name")
    .isFocused($editing)
```

Wears: [KeyboardElement](KeyboardElement.md)

Worn by: [Button](../Button.md) · [CheckBox](../CheckBox.md) · [DatePicker](../DatePicker.md) · [ItemsView](../ItemsView.md) · [Link](../Link.md) · [Picker](../Picker.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Slider](../Slider.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [WebView](../WebView.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/FocusElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `focus` | act | `() -> Bool` |  |
| `isFocusedChanged` | event | `Bool` | native |
| `unfocus` | act | `() -> Void` |  |
