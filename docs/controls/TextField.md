<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextField

A native single-line text field.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [InputView](tiers/InputView.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/TextFieldContract.swift`.

## TextField's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isPassword` | property | `Bool` | native |  |  |  |  |  |  | cannot read isPassword of TextField - AppKit's driver has no path for it yet; Android Views: cannot read isPassword of TextField - Android's driver has no path for it yet |
| `returnKey` | property | `ReturnKey` | adaptive |  |  |  |  |  |  | Android Views: cannot read returnKey of TextField - Android's driver has no path for it yet |
| `showsClearButton` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `onSubmitted` (`submitted`) | event |  | native | ✅ |  | ✅ | ✅ |  |  | WinUI 3: cannot submit on TextField - WinUI raises a text box's KeyDown only from the keyboard; Enter is walked on HelloWorld's field |

Realization:

- **AppKit**: `NSTextField` / `NSSecureTextField`
- **UIKit**: `UITextField`
- **GTK 4**: `GtkEntry` / `GtkPasswordEntry`
- **Android Views**: `EditText`
- **WinUI 3**: `TextBox` / `PasswordBox`
- **Web**: `<input>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of TextField - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of TextField - Android's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of TextField - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHeadingLevel of TextField - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityHint of TextField - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHint of TextField - Android's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityLabel of TextField - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityLabel of TextField - Android's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read automationExcludedWithChildren of TextField - AppKit's driver has no path for it yet; Android Views: cannot read automationExcludedWithChildren of TextField - Android's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  |  |  | cannot read background of TextField - AppKit's driver has no path for it yet; Android Views: cannot read background of TextField - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of TextField - AppKit's driver has no path for it yet |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | cannot read what reaches TextField - AppKit's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isAccessibilityHidden of TextField - AppKit's driver has no path for it yet; Android Views: cannot read isAccessibilityHidden of TextField - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  | ✅ | ✅ | ✅ |  | cannot read isEnabled of TextField - AppKit's driver has no path for it yet |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read the focus of TextField - AppKit's driver has no path for it yet |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotX of TextField - AppKit's driver has no path for it yet; Android Views: cannot read pivotX of TextField - Android's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotY of TextField - AppKit's driver has no path for it yet; Android Views: cannot read pivotY of TextField - Android's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read rotation of TextField - AppKit's driver has no path for it yet; Android Views: cannot read rotation of TextField - Android's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationX of TextField - AppKit's driver has no path for it yet; Android Views: cannot read rotationX of TextField - Android's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationY of TextField - AppKit's driver has no path for it yet; Android Views: cannot read rotationY of TextField - Android's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scale of TextField - AppKit's driver has no path for it yet; Android Views: cannot read scale of TextField - Android's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleX of TextField - AppKit's driver has no path for it yet; Android Views: cannot read scaleX of TextField - Android's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleY of TextField - AppKit's driver has no path for it yet; Android Views: cannot read scaleY of TextField - Android's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationX of TextField - AppKit's driver has no path for it yet; Android Views: cannot read translationX of TextField - Android's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationY of TextField - AppKit's driver has no path for it yet; Android Views: cannot read translationY of TextField - Android's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of TextField - AppKit's driver has no path for it yet |
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
| `panTouchCount` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  |  | ✅ |  | cannot pinch on TextField - AppKit's driver has no path for it yet; Android Views: cannot pinch on TextField - Android's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  |  | ✅ |  | cannot hover on TextField - AppKit's driver has no path for it yet; Android Views: cannot hover on TextField - Android's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  |  | ✅ |  | cannot hover on TextField - AppKit's driver has no path for it yet; Android Views: cannot hover on TextField - Android's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on TextField - AppKit's driver has no path for it yet; Android Views: cannot hover on TextField - Android's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on TextField - AppKit's driver has no path for it yet; Android Views: cannot hover on TextField - Android's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  |  | ✅ |  | cannot hover on TextField - AppKit's driver has no path for it yet; Android Views: cannot hover on TextField - Android's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  |  | ✅ |  | cannot pan on TextField - AppKit's driver has no path for it yet; Android Views: cannot pan on TextField - Android's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  |  | ✅ |  | cannot tap on TextField - AppKit's driver has no path for it yet; Android Views: cannot tap on TextField - Android's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  |  | ✅ |  | cannot tap on TextField - AppKit's driver has no path for it yet; Android Views: cannot tap on TextField - Android's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [InputView](tiers/InputView.md)

What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `cursorPosition` | property | `Int` | native |  |  |  |  | ✅ |  | cannot read cursorPosition of TextField - AppKit's driver has no path for it yet; Android Views: cannot read cursorPosition of TextField - Android's driver has no path for it yet |
| `inputPurpose` | property | `InputPurpose` | adaptive |  |  |  |  | ✅ |  |  |
| `isReadOnly` | property | `Bool` | native | ✅ |  |  |  | ✅ |  |  |
| `isSpellCheckEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isSpellCheckEnabled of TextField - AppKit's driver has no path for it yet |
| `isTextPredictionEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isTextPredictionEnabled of TextField - AppKit's driver has no path for it yet |
| `maximumLength` | property | `Int` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `placeholder` | property | `String` | native |  |  |  |  | ✅ |  | cannot read placeholder of TextField - AppKit's driver has no path for it yet; Android Views: cannot read placeholder of TextField - Android's driver has no path for it yet |
| `placeholderColor` | property | `Color` | native |  |  |  |  | ✅ |  | cannot read placeholderColor of TextField - AppKit's driver has no path for it yet; Android Views: cannot read placeholderColor of TextField - Android's driver has no path for it yet |
| `selectionLength` | property | `Int` | native |  |  |  |  | ✅ |  | cannot read selectionLength of TextField - AppKit's driver has no path for it yet; Android Views: cannot read selectionLength of TextField - Android's driver has no path for it yet |
| `onTextChanged` (`textChanged`) | event | `String` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `textCase` | property | `TextCase` | native |  |  |  |  |  |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  |  |
| `textColor` | property | `Color` | native |  |  |  |  | ✅ |  | cannot read textColor of TextField - AppKit's driver has no path for it yet; Android Views: cannot read textColor of TextField - Android's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native |  |  |  |  | ✅ |  | cannot read fontAttributes of TextField - AppKit's driver has no path for it yet; Android Views: cannot read fontAttributes of TextField - Android's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native |  |  |  |  | ✅ |  | cannot read fontFamily of TextField - AppKit's driver has no path for it yet; Android Views: cannot read fontFamily of TextField - Android's driver has no path for it yet |
| `fontSize` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read fontSize of TextField - AppKit's driver has no path for it yet; Android Views: cannot read fontSize of TextField - Android's driver has no path for it yet |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native |  |  |  |  | ✅ |  | cannot read horizontalTextAlignment of TextField - AppKit's driver has no path for it yet |
| `verticalTextAlignment` | property | `TextAlignment` | native |  |  |  |  |  |  |  |
