<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# KeyboardElement

An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.

```swift
@State var row = 0

VStack {
    Text("Row \(row)")
}
.onKeyPressed(.upArrow, .downArrow) { key in
    row += key == .upArrow ? -1 : 1
}
```

Wears: [PropertyContainer](PropertyContainer.md)

Worn by: [Button](../Button.md) · [CheckBox](../CheckBox.md) · [DatePicker](../DatePicker.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [ItemsView](../ItemsView.md) · [Picker](../Picker.md) · [RadioButton](../RadioButton.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Slider](../Slider.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [VStack](../VStack.md) · [WebView](../WebView.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/KeyboardElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `keyPressed` | event | `Key` | native |
| `keysTaken` | property | `[Key]` | structure |
