<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Slider

A value picked by dragging a thumb along a native track.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TintElement](tiers/TintElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/SliderContract.swift`.

## Slider's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onDragCompleted` (`dragCompleted`) | event |  | native |  |  |  |  |  |  | cannot pressDown on Slider - AppKit's driver has no path for it yet; Android Views: cannot pressDown on Slider - Android's driver has no path for it yet |
| `onDragStarted` (`dragStarted`) | event |  | native |  |  |  |  |  |  | cannot pressDown on Slider - AppKit's driver has no path for it yet; Android Views: cannot pressDown on Slider - Android's driver has no path for it yet |
| `maximum` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimum` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `value` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onValueChanged` (`valueChanged`) | event | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

Realization:

- **AppKit**: `NSSlider`
- **UIKit**: `UISlider`
- **GTK 4**: `GtkScale`
- **Android Views**: `SeekBar`
- **WinUI 3**: `Slider`
- **Web**: `<input type=range>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of Slider - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of Slider - Android's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of Slider - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHeadingLevel of Slider - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityHint of Slider - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHint of Slider - Android's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityLabel of Slider - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityLabel of Slider - Android's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read automationExcludedWithChildren of Slider - AppKit's driver has no path for it yet; Android Views: cannot read automationExcludedWithChildren of Slider - Android's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  |  |  | cannot read background of Slider - AppKit's driver has no path for it yet; Android Views: cannot read background of Slider - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of Slider - AppKit's driver has no path for it yet |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | cannot read what reaches Slider - AppKit's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isAccessibilityHidden of Slider - AppKit's driver has no path for it yet; Android Views: cannot read isAccessibilityHidden of Slider - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read the focus of Slider - AppKit's driver has no path for it yet |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotX of Slider - AppKit's driver has no path for it yet; Android Views: cannot read pivotX of Slider - Android's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotY of Slider - AppKit's driver has no path for it yet; Android Views: cannot read pivotY of Slider - Android's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read rotation of Slider - AppKit's driver has no path for it yet; Android Views: cannot read rotation of Slider - Android's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationX of Slider - AppKit's driver has no path for it yet; Android Views: cannot read rotationX of Slider - Android's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationY of Slider - AppKit's driver has no path for it yet; Android Views: cannot read rotationY of Slider - Android's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scale of Slider - AppKit's driver has no path for it yet; Android Views: cannot read scale of Slider - Android's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleX of Slider - AppKit's driver has no path for it yet; Android Views: cannot read scaleX of Slider - Android's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleY of Slider - AppKit's driver has no path for it yet; Android Views: cannot read scaleY of Slider - Android's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationX of Slider - AppKit's driver has no path for it yet; Android Views: cannot read translationX of Slider - Android's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationY of Slider - AppKit's driver has no path for it yet; Android Views: cannot read translationY of Slider - Android's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of Slider - AppKit's driver has no path for it yet |
| `width` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  |  |
| `area` | property | `Area` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  |  | ✅ |  | cannot pinch on Slider - AppKit's driver has no path for it yet; Android Views: cannot pinch on Slider - Android's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  |  | ✅ |  | cannot hover on Slider - AppKit's driver has no path for it yet; Android Views: cannot hover on Slider - Android's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  |  | ✅ |  | cannot hover on Slider - AppKit's driver has no path for it yet; Android Views: cannot hover on Slider - Android's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on Slider - AppKit's driver has no path for it yet; Android Views: cannot hover on Slider - Android's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on Slider - AppKit's driver has no path for it yet; Android Views: cannot hover on Slider - Android's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on Slider - AppKit's driver has no path for it yet; Android Views: cannot hover on Slider - Android's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  |  | ✅ |  | cannot pan on Slider - AppKit's driver has no path for it yet; Android Views: cannot pan on Slider - Android's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot tap on Slider - AppKit's driver has no path for it yet; Android Views: cannot tap on Slider - Android's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  |  | ✅ |  | cannot tap on Slider - AppKit's driver has no path for it yet; Android Views: cannot tap on Slider - Android's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [TintElement](tiers/TintElement.md)

A control's one accent colour.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `tint` | property | `Color` | adaptive |  |  |  |  | ✅ |  | cannot read tint of Slider - AppKit's driver has no path for it yet; Android Views: cannot read tint of Slider - Android's driver has no path for it yet |
