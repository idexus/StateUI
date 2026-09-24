<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# VisualElement

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

Wears: [PropertyContainer](PropertyContainer.md)

Worn by: [ActivityIndicator](../ActivityIndicator.md) · [Button](../Button.md) · [Canvas](../Canvas.md) · [CheckBox](../CheckBox.md) · [ColorBox](../ColorBox.md) · [DatePicker](../DatePicker.md) · [Ellipse](../Ellipse.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [Image](../Image.md) · [Label](../Label.md) · [Line](../Line.md) · [Map](../Map.md) · [Path](../Path.md) · [Picker](../Picker.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [PositionIndicator](../PositionIndicator.md) · [ProgressBar](../ProgressBar.md) · [RadioButton](../RadioButton.md) · [Rectangle](../Rectangle.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Slider](../Slider.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [TitleBar](../TitleBar.md) · [VStack](../VStack.md) · [WebView](../WebView.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/VisualElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |
| `accessibilityHint` | property | `String` | native |
| `accessibilityLabel` | property | `String` | native |
| `automationExcludedWithChildren` | property | `Bool` | native |
| `background` | property | `Background` | native |
| `focus` | act | `() -> Bool` |  |
| `frame` | property | `Rect` | structure |
| `height` | property | `Double` | native |
| `ignoresInput` | property | `Bool` | native |
| `isAccessibilityHidden` | property | `Bool` | native |
| `isEnabled` | property | `Bool` | native |
| `isFocusedChanged` | event | `Bool` | native |
| `isVisible` | property | `Bool` | native |
| `layoutDirection` | property | `LayoutDirection` | native |
| `maximumHeight` | property | `Double` | native |
| `maximumWidth` | property | `Double` | native |
| `minimumHeight` | property | `Double` | native |
| `minimumWidth` | property | `Double` | native |
| `opacity` | property | `Double` | native |
| `pivotX` | property | `Double` | native |
| `pivotY` | property | `Double` | native |
| `rotation` | property | `Double` | native |
| `rotationX` | property | `Double` | native |
| `rotationY` | property | `Double` | native |
| `scale` | property | `Double` | native |
| `scaleX` | property | `Double` | native |
| `scaleY` | property | `Double` | native |
| `style` | property | `Name` | structure |
| `translationX` | property | `Double` | native |
| `translationY` | property | `Double` | native |
| `unfocus` | act | `() -> Void` |  |
| `onVisualStateChanged` (`visualStateChanged`) | event | `String` | stateUI |
| `width` | property | `Double` | native |
| `zIndex` | property | `Int` | native |
