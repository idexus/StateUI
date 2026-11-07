<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# EnabledElement

Whether the user's hand reaches an element: a view, a menu, an entry in one, a toolbar's group.

```swift
@State var name = ""

Button("Send")
    .isEnabled(!name.isEmpty)
```

Worn by: [Button](../Button.md) · [Canvas](../Canvas.md) · [Capsule](../Capsule.md) · [CheckBox](../CheckBox.md) · [ColorPicker](../ColorPicker.md) · [DatePicker](../DatePicker.md) · [Ellipse](../Ellipse.md) · [Fill](../Fill.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [Image](../Image.md) · [ItemsView](../ItemsView.md) · [Line](../Line.md) · [Link](../Link.md) · [Map](../Map.md) · [Menu](../Menu.md) · [MenuItem](../MenuItem.md) · [MenuToggle](../MenuToggle.md) · [MotionLayout](../MotionLayout.md) · [Path](../Path.md) · [Picker](../Picker.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [ProgressBar](../ProgressBar.md) · [Rectangle](../Rectangle.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Separator](../Separator.md) · [Slider](../Slider.md) · [Space](../Space.md) · [Spinner](../Spinner.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [ToolbarButton](../ToolbarButton.md) · [ToolbarGroup](../ToolbarGroup.md) · [ToolbarToggle](../ToolbarToggle.md) · [VStack](../VStack.md) · [WebView](../WebView.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/EnabledElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `isEnabled` | property | `Bool` | native |
