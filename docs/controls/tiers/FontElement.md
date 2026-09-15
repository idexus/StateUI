<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# FontElement

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the reader's text-size setting.

Wears: [PropertyContainer](PropertyContainer.md)

Worn by: [Button](../Button.md) · [DatePicker](../DatePicker.md) · [Label](../Label.md) · [Picker](../Picker.md) · [RadioButton](../RadioButton.md) · [SearchField](../SearchField.md) · [Span](../Span.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/FontElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `fontAttributes` | property | `FontAttributes` | native |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |
| `fontFamily` | property | `Name` | native |
| `fontSize` | property | `Double` | native |
