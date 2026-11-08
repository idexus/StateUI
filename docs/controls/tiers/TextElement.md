<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextElement

The words an element shows: a control's caption, a text's or a field's words, a menu's caption and its items', a bar's label.

```swift
@State var count = 0

Button("Clicked \(count) times")
    .onClicked { count += 1 }
```

Worn by: [Button](../Button.md) · [CheckBox](../CheckBox.md) · [Link](../Link.md) · [Menu](../Menu.md) · [MenuItem](../MenuItem.md) · [MenuToggle](../MenuToggle.md) · [SearchField](../SearchField.md) · [Switch](../Switch.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TextSpan](../TextSpan.md) · [ToolbarButton](../ToolbarButton.md) · [ToolbarLabel](../ToolbarLabel.md) · [ToolbarToggle](../ToolbarToggle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/TextElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `text` | property | `String` | native |
