<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Image

A picture from the application's resources.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [ImageElement](tiers/ImageElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/ImageContract.swift`.

## Image's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isAnimating` | property | `Bool` | native |  |  |  |  |  |  | cannot read isAnimating of Image - AppKit's driver has no path for it yet |
| `source` | property | `ImageSource` | native | ✅ | ✅ |  | ✅ | ✅ |  |  |

Realization:

- **AppKit**: `NSImageView`
- **UIKit**: `UIImageView`
- **GTK 4**: `GtkPicture`
- **Android Views**: `ImageView`
- **WinUI 3**: `Image`
- **Web**: `<img>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ |  |  | ✅ | ✅ |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read a heading's level: AppKit marks a heading, not its level - AppKit's driver has no path for it yet; Android Views: cannot read a heading's level: Android marks a heading, not its level - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read accessibilityHint of Image - UIKit's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read accessibilityLabel of Image - UIKit's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `background` | property | `Background` | native | ☑️ |  |  | ✅ |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout. |
| `focus` | act | `() -> Bool` |  | ✅ |  |  | ✅ | ✅ |  |  |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isEnabled` | property | `Bool` | native |  |  | ✅ |  |  |  | UIKit: cannot read isEnabled of Image - UIKit's driver has no path for it yet |
| `isFocusedChanged` | event | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read pivotX of Image - UIKit's driver has no path for it yet |
| `pivotY` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read pivotY of Image - UIKit's driver has no path for it yet |
| `rotation` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read rotation of Image - UIKit's driver has no path for it yet |
| `rotationX` | property | `Double` | native | ✅ |  |  | ✅ |  |  | UIKit: cannot read rotationX of Image - UIKit's driver has no path for it yet |
| `rotationY` | property | `Double` | native | ✅ |  |  | ✅ |  |  | UIKit: cannot read rotationY of Image - UIKit's driver has no path for it yet |
| `scale` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read scale of Image - UIKit's driver has no path for it yet |
| `scaleX` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read scaleX of Image - UIKit's driver has no path for it yet |
| `scaleY` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read scaleY of Image - UIKit's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read translationX of Image - UIKit's driver has no path for it yet |
| `translationY` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read translationY of Image - UIKit's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  | ✅ |  |  | ✅ | ✅ |  |  |
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
| `panTouchCount` | property | `Int` | structure | ☑️ |  |  | ✅ | ✅ |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `panXChannel` | property | `Int` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `panYChannel` | property | `Int` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `swipeThreshold` | property | `Double` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `tapCount` | property | `Int` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `onTapped` (`tapped`) | event |  | native | ✅ |  |  | ✅ | ✅ |  |  |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [ImageElement](tiers/ImageElement.md)

How a picture fills the room it was given.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: cannot read aspect of Image - UIKit's driver has no path for it yet |
