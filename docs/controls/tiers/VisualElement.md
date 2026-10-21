<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# VisualElement

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

```swift
@State var busy = false

Button("Send")
    .isEnabled(!busy)
    .opacity(busy ? 0.5 : 1)
    .width(120)
    .accessibilityHint("Sends the message")
```

Wears: [AutomationElement](AutomationElement.md)

Worn by: [ActivityIndicator](../ActivityIndicator.md) · [Button](../Button.md) · [Canvas](../Canvas.md) · [Capsule](../Capsule.md) · [CheckBox](../CheckBox.md) · [DatePicker](../DatePicker.md) · [Divider](../Divider.md) · [Ellipse](../Ellipse.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [Image](../Image.md) · [ItemsView](../ItemsView.md) · [LayoutEngine](../LayoutEngine.md) · [Line](../Line.md) · [Map](../Map.md) · [Path](../Path.md) · [Picker](../Picker.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [ProgressBar](../ProgressBar.md) · [Rectangle](../Rectangle.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Slider](../Slider.md) · [Spacer](../Spacer.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [VStack](../VStack.md) · [WebView](../WebView.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Tiers/VisualElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `accessibilityHeading` | property | `AccessibilityHeadingLevel` | native |
| `accessibilityHint` | property | `String` | native |
| `accessibilityLabel` | property | `String` | native |
| `accessibilityRole` | property | `AccessibilityRole` | native |
| `accessibilityValue` | property | `String` | native |
| `background` | property | `Material` | adaptive |
| `frame` | property | `Rect` | structure |
| `height` | property | `Double` | native |
| `hidesChildrenFromAccessibility` | property | `Bool` | native |
| `ignoresInput` | property | `Bool` | native |
| `isAccessibilityHidden` | property | `Bool` | native |
| `isEnabled` | property | `Bool` | native |
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
| `tooltip` | property | `String` | native |
| `translationX` | property | `Double` | native |
| `translationY` | property | `Double` | native |
| `width` | property | `Double` | native |
| `zIndex` | property | `Int` | native |
