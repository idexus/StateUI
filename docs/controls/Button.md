<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Button

A button with a caption, and a handler for the press.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md) · [ImageElement](tiers/ImageElement.md)

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/ButtonContract.swift`.

## Button's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `icon` | property | `ImageSource` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `iconPosition` | property | `IconPosition` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `iconSpacing` | property | `Double` | adaptive | ✅ |  |  |  |  |  |  |  |
| `lineBreak` | property | `LineBreak` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPressed` (`pressed`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `onReleased` (`released`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `Button`
- **AppKit**: `NSButton`
- **UIKit**: `UIButton`
- **GTK 4**: `GtkButton`
- **Android Views**: `Button`
- **WinUI 3**: `Button`
- **Web**: `<button>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ✅ | ✅ |  |  |  |  |  |  |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `background` | property | `Background` | native | ✅ | ☑️ |  |  |  |  |  | AppKit paints a colour on this view; a brush is drawn only by `Border`. |
| `focus` | act | `() -> Bool` |  | ✅ | ✅ |  |  |  |  |  |  |
| `frame` | property | `Rect` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `height` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isVisible` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `layoutDirection` | property | `LayoutDirection` | native | ✅ |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `pivotX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `pivotY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `rotation` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `rotationX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `rotationY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `scale` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `scaleX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `scaleY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `translationY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `unfocus` | act | `() -> Void` |  | ✅ | ✅ |  |  |  |  |  |  |
| `onVisualStateChanged` (`visualStateChanged`) | event | `String` | stateUI | ✅ |  |  |  |  |  |  |  |
| `width` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `zIndex` | property | `Int` | native | ✅ |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `absoluteLayoutBounds` | property | `Rect` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `absoluteLayoutProportions` | property | `AbsoluteLayoutProportions` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `allowDrop` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `canDrag` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native | ✅ |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native | ✅ |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native | ✅ |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ |  |  |  |  |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ |  |  |  |  |  |  |
| `margin` | property | `Insets` | native | ✅ | ✅ |  |  |  |  |  |  |
| `panTouchCount` | property | `Int` | structure | ✅ | ☑️ |  |  |  |  |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ | ✅ |  |  |  |  |  |  |
| `panXChannel` | property | `Int` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `panYChannel` | property | `Int` | structure | ✅ |  |  |  |  |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ | ✅ |  |  |  |  |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `swipeThreshold` | property | `Double` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ | ✅ |  |  |  |  |  |  |
| `tapCount` | property | `Int` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `onTapped` (`tapped`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `textCase` | property | `TextCase` | native | ✅ |  |  |  |  |  |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native | ✅ |  |  |  |  |  |  |  |
| `textColor` | property | `Color` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the reader's text-size setting.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ | ✅ |  |  |  |  |  |  |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive | ✅ |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native | ✅ | ✅ |  |  |  |  |  |  |
| `fontSize` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [BorderElement](tiers/BorderElement.md)

The line around a control's own box, and how round its corners are.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `borderColor` | property | `Color` | native | ✅ | ✅ |  |  |  |  |  |  |
| `borderWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `cornerRadius` | property | `Int` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [ImageElement](tiers/ImageElement.md)

How a picture fills the room it was given.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ✅ | ☑️ |  |  |  |  |  | AppKit's button has no covering scale: `.fill` fits the icon, as `.fit` does. |
