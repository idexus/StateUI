<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Button

A button with a caption, and a handler for the press.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md) · [ImageElement](tiers/ImageElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/ButtonContract.swift`.

## Button's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `icon` | property | `ImageSource` | adaptive |  |  |  |  |  |  | cannot read icon of Button - AppKit's driver has no path for it yet; Android Views: cannot read icon of Button - Android's driver has no path for it yet |
| `iconPosition` | property | `IconPosition` | adaptive |  |  |  |  |  |  | cannot read iconPosition of Button - AppKit's driver has no path for it yet; Android Views: cannot read iconPosition of Button - Android's driver has no path for it yet |
| `iconSpacing` | property | `Double` | adaptive |  |  |  |  |  |  | Android Views: cannot read iconSpacing of Button - Android's driver has no path for it yet |
| `lineBreak` | property | `LineBreak` | native |  |  |  |  |  |  | cannot read lineBreak of Button - AppKit's driver has no path for it yet; Android Views: cannot read lineBreak of Button - Android's driver has no path for it yet |
| `onPressed` (`pressed`) | event |  | native |  |  |  |  | ✅ |  | cannot pressDown on Button - AppKit's driver has no path for it yet; Android Views: cannot pressDown on Button - Android's driver has no path for it yet |
| `onReleased` (`released`) | event |  | native |  |  |  |  | ✅ |  | cannot pressDown on Button - AppKit's driver has no path for it yet; Android Views: cannot pressDown on Button - Android's driver has no path for it yet |

Realization:

- **AppKit**: `NSButton`
- **UIKit**: `UIButton`
- **GTK 4**: `GtkButton`
- **Android Views**: `Button`
- **WinUI 3**: `Button`
- **Web**: `<button>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of Button - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of Button - Android's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of Button - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHeadingLevel of Button - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityHint of Button - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHint of Button - Android's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityLabel of Button - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityLabel of Button - Android's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read automationExcludedWithChildren of Button - AppKit's driver has no path for it yet; Android Views: cannot read automationExcludedWithChildren of Button - Android's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  | ✅ |  | cannot read background of Button - AppKit's driver has no path for it yet; Android Views: cannot read background of Button - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of Button - AppKit's driver has no path for it yet |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | cannot read what reaches Button - AppKit's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isAccessibilityHidden of Button - AppKit's driver has no path for it yet; Android Views: cannot read isAccessibilityHidden of Button - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read the focus of Button - AppKit's driver has no path for it yet |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotX of Button - AppKit's driver has no path for it yet; Android Views: cannot read pivotX of Button - Android's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotY of Button - AppKit's driver has no path for it yet; Android Views: cannot read pivotY of Button - Android's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read rotation of Button - AppKit's driver has no path for it yet; Android Views: cannot read rotation of Button - Android's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationX of Button - AppKit's driver has no path for it yet; Android Views: cannot read rotationX of Button - Android's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationY of Button - AppKit's driver has no path for it yet; Android Views: cannot read rotationY of Button - Android's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scale of Button - AppKit's driver has no path for it yet; Android Views: cannot read scale of Button - Android's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleX of Button - AppKit's driver has no path for it yet; Android Views: cannot read scaleX of Button - Android's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleY of Button - AppKit's driver has no path for it yet; Android Views: cannot read scaleY of Button - Android's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationX of Button - AppKit's driver has no path for it yet; Android Views: cannot read translationX of Button - Android's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationY of Button - AppKit's driver has no path for it yet; Android Views: cannot read translationY of Button - Android's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of Button - AppKit's driver has no path for it yet |
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
| `panTouchCount` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  |  | ✅ |  | cannot pinch on Button - AppKit's driver has no path for it yet; Android Views: cannot pinch on Button - Android's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  |  | ✅ |  | cannot hover on Button - AppKit's driver has no path for it yet; Android Views: cannot hover on Button - Android's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  |  | ✅ |  | cannot hover on Button - AppKit's driver has no path for it yet; Android Views: cannot hover on Button - Android's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on Button - AppKit's driver has no path for it yet; Android Views: cannot hover on Button - Android's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on Button - AppKit's driver has no path for it yet; Android Views: cannot hover on Button - Android's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on Button - AppKit's driver has no path for it yet; Android Views: cannot hover on Button - Android's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  |  | ✅ |  | cannot pan on Button - AppKit's driver has no path for it yet; Android Views: cannot pan on Button - Android's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot tap on Button - AppKit's driver has no path for it yet; Android Views: cannot tap on Button - Android's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  |  | ✅ |  | cannot tap on Button - AppKit's driver has no path for it yet; Android Views: cannot tap on Button - Android's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `textCase` | property | `TextCase` | native |  |  | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  |  |
| `textColor` | property | `Color` | native |  |  |  |  | ✅ |  | cannot read textColor of Button - AppKit's driver has no path for it yet; Android Views: cannot read textColor of Button - Android's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native |  |  |  |  | ✅ |  | cannot read fontAttributes of Button - AppKit's driver has no path for it yet; Android Views: cannot read fontAttributes of Button - Android's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native |  |  |  |  | ✅ |  | cannot read fontFamily of Button - AppKit's driver has no path for it yet; Android Views: cannot read fontFamily of Button - Android's driver has no path for it yet |
| `fontSize` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read fontSize of Button - AppKit's driver has no path for it yet; Android Views: cannot read fontSize of Button - Android's driver has no path for it yet |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native |  |  |  |  | ✅ |  | cannot read padding of Button - AppKit's driver has no path for it yet; Android Views: cannot read padding of Button - Android's driver has no path for it yet |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI |  |  |  |  | ✅ |  | cannot read shape of Button - AppKit's driver has no path for it yet; Android Views: cannot read shape of Button - Android's driver has no path for it yet |
| `stroke` | property | `Brush` | stateUI |  |  |  |  | ✅ |  | cannot read stroke of Button - AppKit's driver has no path for it yet; Android Views: cannot read stroke of Button - Android's driver has no path for it yet |
| `strokeWidth` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeWidth of Button - AppKit's driver has no path for it yet; Android Views: cannot read strokeWidth of Button - Android's driver has no path for it yet |

## From [ImageElement](tiers/ImageElement.md)

How a picture fills the room it was given.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native |  |  |  |  |  |  | cannot read aspect of Button - AppKit's driver has no path for it yet; Android Views: cannot read aspect of Button - Android's driver has no path for it yet |
