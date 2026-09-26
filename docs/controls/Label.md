<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Label

A read-only piece of text.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md) · [PaddingElement](tiers/PaddingElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/LabelContract.swift`.

## Label's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineBreak` | property | `LineBreak` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `maximumLines` | property | `Int` | native | ✅ |  |  | ✅ | ✅ |  |  |

Realization:

- **AppKit**: `NSTextField` label; `NSAttributedString` runs
- **UIKit**: `UILabel`; `NSAttributedString` runs
- **GTK 4**: `GtkLabel`; `PangoAttrList` runs
- **Android Views**: `TextView`; `SpannableString` spans
- **WinUI 3**: `TextBlock`; `Run` inlines
- **Web**: text element; `<span>` runs

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityIdentifier of Label - AppKit's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of Label - AppKit's driver has no path for it yet; Android Views: cannot read a heading's level: Android marks a heading, not its level - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityHint of Label - AppKit's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityLabel of Label - AppKit's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read automationExcludedWithChildren of Label - AppKit's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  |  |  | cannot read background of Label - AppKit's driver has no path for it yet; Android Views: cannot read background of Label - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  | ✅ |  |  | ✅ | ✅ |  |  |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read isAccessibilityHidden of Label - AppKit's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  | ✅ |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read pivotX of Label - AppKit's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read pivotY of Label - AppKit's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read rotation of Label - AppKit's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  | ✅ |  |  | cannot read rotationX of Label - AppKit's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  | ✅ |  |  | cannot read rotationY of Label - AppKit's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scale of Label - AppKit's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scaleX of Label - AppKit's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scaleY of Label - AppKit's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read translationX of Label - AppKit's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read translationY of Label - AppKit's driver has no path for it yet |
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

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `textCase` | property | `TextCase` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read characterSpacing of Label - AppKit's driver has no path for it yet; Android Views: cannot read characterSpacing of Label - Android's driver has no path for it yet |
| `textColor` | property | `Color` | native |  |  |  | ✅ | ✅ |  | cannot read textColor of Label - AppKit's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native |  |  |  | ✅ | ✅ |  | cannot read fontAttributes of Label - AppKit's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native |  |  |  |  | ✅ |  | cannot read fontFamily of Label - AppKit's driver has no path for it yet; Android Views: cannot read a family: Android's typeface keeps no family's name - Android's driver has no path for it yet |
| `fontSize` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read fontSize of Label - AppKit's driver has no path for it yet |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native |  |  |  |  | ✅ |  | cannot read horizontalTextAlignment of Label - AppKit's driver has no path for it yet; Android Views: cannot read horizontalTextAlignment of Label - Android's driver has no path for it yet |
| `verticalTextAlignment` | property | `TextAlignment` | native |  |  |  |  |  |  | cannot read verticalTextAlignment of Label - AppKit's driver has no path for it yet; Android Views: cannot read verticalTextAlignment of Label - Android's driver has no path for it yet |

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineHeight` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read lineHeight of Label - AppKit's driver has no path for it yet; Android Views: cannot read lineHeight of Label - Android's driver has no path for it yet |

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `textDecorations` | property | `TextDecorations` | native |  |  |  |  | ✅ |  | cannot read textDecorations of Label - AppKit's driver has no path for it yet; Android Views: cannot read textDecorations of Label - Android's driver has no path for it yet |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native |  |  |  |  | ✅ |  | cannot read padding of Label - AppKit's driver has no path for it yet; Android Views: cannot read padding of Label - Android's driver has no path for it yet |
