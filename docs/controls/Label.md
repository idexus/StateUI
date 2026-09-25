<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Label

A read-only piece of text.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md) · [PaddingElement](tiers/PaddingElement.md)

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · – not planned for that host's family, which meets the contract there - the note says why · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/LabelContract.swift`.

## Label's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineBreak` | property | `LineBreak` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumLines` | property | `Int` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

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
| `accessibilityIdentifier` | property | `String` | native | ✅ |  |  | ✅ | ✅ |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ✅ |  | ✅ | ☑️ | ✅ |  | Android Views: Android marks a heading, not its level: every level is a heading. |
| `accessibilityHint` | property | `String` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `background` | property | `Background` | native | ☑️ |  |  | ✅ |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout. |
| `focus` | act | `() -> Bool` |  | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `frame` | property | `Rect` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotY` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `rotation` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `rotationX` | property | `Double` | native | ✅ |  | ✅ | ✅ |  |  |  |
| `rotationY` | property | `Double` | native | ✅ |  | ✅ | ✅ |  |  |  |
| `scale` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `scaleX` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `scaleY` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `translationY` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `unfocus` | act | `() -> Void` |  | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `width` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  |  |
| `area` | property | `Area` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure | ☑️ |  | ✅ | ✅ | ✅ |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `panXChannel` | property | `Int` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `panYChannel` | property | `Int` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `swipeThreshold` | property | `Double` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `tapCount` | property | `Int` | structure | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `onTapped` (`tapped`) | event |  | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
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
| `characterSpacing` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `textColor` | property | `Color` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `fontSize` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `verticalTextAlignment` | property | `TextAlignment` | native | ✅ |  |  | ✅ |  |  |  |

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `textDecorations` | property | `TextDecorations` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
