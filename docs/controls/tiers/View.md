<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# View

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

Wears: [VisualElement](VisualElement.md)

Worn by: [AbsoluteLayout](../AbsoluteLayout.md) · [ActivityIndicator](../ActivityIndicator.md) · [Border](../Border.md) · [Button](../Button.md) · [Canvas](../Canvas.md) · [CheckBox](../CheckBox.md) · [ColorBox](../ColorBox.md) · [DatePicker](../DatePicker.md) · [Ellipse](../Ellipse.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [Image](../Image.md) · [Label](../Label.md) · [Line](../Line.md) · [Map](../Map.md) · [Path](../Path.md) · [Picker](../Picker.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [PositionIndicator](../PositionIndicator.md) · [ProgressBar](../ProgressBar.md) · [RadioButton](../RadioButton.md) · [Rectangle](../Rectangle.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Slider](../Slider.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [TitleBar](../TitleBar.md) · [VStack](../VStack.md) · [WebView](../WebView.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/ViewContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `absoluteLayoutBounds` | property | `Rect` | structure |
| `absoluteLayoutProportions` | property | `AbsoluteLayoutProportions` | structure |
| `allowDrop` | property | `Bool` | native |
| `canDrag` | property | `Bool` | native |
| `onDragLeave` (`dragLeave`) | event |  | native |
| `onDragOver` (`dragOver`) | event |  | native |
| `dragStarting` | event |  | native |
| `dragText` | property | `String` | native |
| `onDrop` (`drop`) | event | `String` | native |
| `onDropCompleted` (`dropCompleted`) | event |  | native |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |
| `gridColumn` | property | `Int` | stateUI |
| `gridColumnSpan` | property | `Int` | stateUI |
| `gridRow` | property | `Int` | stateUI |
| `gridRowSpan` | property | `Int` | stateUI |
| `horizontalAlignment` | property | `Alignment` | native |
| `margin` | property | `Insets` | native |
| `panTouchCount` | property | `Int` | structure |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |
| `panXChannel` | property | `Int` | structure |
| `panYChannel` | property | `Int` | structure |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |
| `onPointerEntered` (`pointerEntered`) | event |  | native |
| `onPointerExited` (`pointerExited`) | event |  | native |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |
| `swipeDirection` | property | `SwipeDirection` | structure |
| `swipeThreshold` | property | `Double` | structure |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |
| `tapCount` | property | `Int` | structure |
| `onTapped` (`tapped`) | event |  | native |
| `verticalAlignment` | property | `Alignment` | native |
