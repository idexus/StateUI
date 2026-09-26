<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Picker

One choice out of a list.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [TintElement](tiers/TintElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/PickerContract.swift`.

## Picker's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | event |  | native |  |  |  |  | ✅ |  | cannot read isOpen of Picker - AppKit's driver has no path for it yet; Android Views: cannot open on Picker - Android's driver has no path for it yet |
| `isOpen` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isOpen of Picker - AppKit's driver has no path for it yet; Android Views: cannot open on Picker - Android's driver has no path for it yet |
| `onOpened` (`opened`) | event |  | native |  |  |  |  | ✅ |  | cannot read isOpen of Picker - AppKit's driver has no path for it yet; Android Views: cannot open on Picker - Android's driver has no path for it yet |
| `options` | property | `[String]` | structure | ✅ |  | ✅ |  | ✅ |  | Android Views: cannot read options of Picker - Android's driver has no path for it yet |
| `selectedIndex` | property | `Int` | native | ✅ |  | ✅ |  | ✅ |  | Android Views: cannot choose on Picker - Android's driver has no path for it yet |
| `onSelectedIndexChanged` (`selectedIndexChanged`) | event | `Int` | native | ✅ |  | ✅ |  | ✅ |  | Android Views: cannot choose on Picker - Android's driver has no path for it yet |
| `title` | property | `String` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot read title of Picker - Android's driver has no path for it yet |

Realization:

- **AppKit**: `NSPopUpButton`
- **UIKit**: pop-up `UIButton` menu
- **GTK 4**: `GtkDropDown`
- **Android Views**: `Spinner`
- **WinUI 3**: `ComboBox`
- **Web**: `<select>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityIdentifier of Picker - AppKit's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of Picker - AppKit's driver has no path for it yet; Android Views: cannot read a heading's level: Android marks a heading, not its level - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityHint of Picker - AppKit's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityLabel of Picker - AppKit's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read automationExcludedWithChildren of Picker - AppKit's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  | ✅ |  |  | cannot read background of Picker - AppKit's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  | ✅ |  |  | ✅ | ✅ |  |  |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read isAccessibilityHidden of Picker - AppKit's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read pivotX of Picker - AppKit's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read pivotY of Picker - AppKit's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read rotation of Picker - AppKit's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  | ✅ |  |  | cannot read rotationX of Picker - AppKit's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  | ✅ |  |  | cannot read rotationY of Picker - AppKit's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scale of Picker - AppKit's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scaleX of Picker - AppKit's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scaleY of Picker - AppKit's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read translationX of Picker - AppKit's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read translationY of Picker - AppKit's driver has no path for it yet |
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

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  |  |
| `textColor` | property | `Color` | native |  |  |  |  | ✅ |  | cannot read textColor of Picker - AppKit's driver has no path for it yet; Android Views: cannot read textColor of Picker - Android's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native |  |  |  |  | ✅ |  | cannot read fontAttributes of Picker - AppKit's driver has no path for it yet; Android Views: cannot read fontAttributes of Picker - Android's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native |  |  |  |  | ✅ |  | cannot read fontFamily of Picker - AppKit's driver has no path for it yet; Android Views: cannot read fontFamily of Picker - Android's driver has no path for it yet |
| `fontSize` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read fontSize of Picker - AppKit's driver has no path for it yet; Android Views: cannot read fontSize of Picker - Android's driver has no path for it yet |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native |  |  |  |  | ✅ |  | cannot read horizontalTextAlignment of Picker - AppKit's driver has no path for it yet; Android Views: cannot read horizontalTextAlignment of Picker - Android's driver has no path for it yet |
| `verticalTextAlignment` | property | `TextAlignment` | native |  |  |  |  |  |  |  |

## From [TintElement](tiers/TintElement.md)

A control's one accent colour.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `tint` | property | `Color` | adaptive |  |  |  |  | ✅ |  | cannot read tint of Picker - AppKit's driver has no path for it yet; Android Views: cannot read tint of Picker - Android's driver has no path for it yet |
