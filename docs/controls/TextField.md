<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextField

A native single-line text field.

```swift
@State var name = ""
@State var greeting = ""

TextField($name)
    .placeholder("Your name")
    .showsClearButton(true)
    .onSubmitted { greeting = "Hello, \(name)" }
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [InputView](tiers/InputView.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (90) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 42 ✅ · 1 ☑️ · 3 – · 26 🔌 | `NSTextField` / `NSSecureTextField` |  |
| UIKit | ✅ | 49 ✅ · 25 🔌 | `UITextField` |  |
| Android Views | ✅ | 66 ✅ · 1 ☑️ · 1 – | `EditText` |  |
| WinUI 3 | ✅ | 69 ✅ · 1 ☑️ | `TextBox` / `PasswordBox` |  |
| GTK 4 | ✅ | 60 ✅ · 1 – · 12 🔌 | `GtkEntry` / `GtkPasswordEntry` |  |
| Web |  |  | `<input>` | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Text/TextFieldContract.swift`.

## TextField's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isPassword` | property | `Bool` | native | ✅ | ✅ | ✅ | ☑️ | ✅ |  | WinUI 3: A PasswordBox has no read-only state, alignment, case, caret or selection: a password field keeps none of these. |
| `returnKey` | property | `ReturnKey` | adaptive | – | ✅ | · |  |  |  | A Mac has no keyboard on the screen whose return key says anything.; Android Views: cannot read returnKey of TextField - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `showsClearButton` | property | `Bool` | adaptive | – | ✅ |  |  |  |  | AppKit's text field has no button of its own that empties it.; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onSubmitted` (`submitted`) | event |  | native | ✅ | ✅ | ✅ | · | ✅ |  | WinUI 3: cannot submit on TextField - WinUI raises a text box's KeyDown only from the keyboard; Enter is walked on HelloWorld's field |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | – |  | GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code. |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | ✅ |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ | ✅ |  |  |  |  | Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | ◐ | ✅ | ✅ |  | Android Views: waits on TextField.isReadOnly |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read pivotX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotX of TextField: the host's own transform: GTK reads back no part of one |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read pivotY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotY of TextField: the host's own transform: GTK reads back no part of one |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read rotation of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotation of TextField: the host's own transform: GTK reads back no part of one |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | 🔌 |  | only through the host's own: read rotationX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of TextField: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationX of TextField: the host's own transform: GTK reads back no part of one |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | 🔌 |  | only through the host's own: read rotationY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of TextField: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationY of TextField: the host's own transform: GTK reads back no part of one |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read scale of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scale of TextField: the host's own transform: GTK reads back no part of one |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read scaleX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleX of TextField: the host's own transform: GTK reads back no part of one |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read scaleY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleY of TextField: the host's own transform: GTK reads back no part of one |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read translationX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationX of TextField: the host's own transform: GTK reads back no part of one |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read translationY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationY of TextField: the host's own transform: GTK reads back no part of one |
| `unfocus` | act | `() -> Void` |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `width` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: pinch on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: only through the host's own: pinch on TextField: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TextField: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TextField: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [InputView](tiers/InputView.md)

What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `cursorPosition` | property | `Int` | native | · | ✅ | ✅ | ✅ | ✅ |  | cannot read cursorPosition of TextField - AppKit's driver has no path for it yet |
| `inputPurpose` | property | `InputPurpose` | adaptive | 🔌 | ✅ | ✅ | ✅ | ✅ |  | only through the host's own: read inputPurpose of TextField: the traits the host keeps; a Mac shows no keys a purpose picks |
| `isReadOnly` | property | `Bool` | native | ✅ | ✅ |  | ✅ | ✅ |  | Android Views: not realized |
| `isSpellCheckEnabled` | property | `Bool` | native | · | ✅ | – | ✅ | ✅ |  | cannot read isSpellCheckEnabled of TextField - AppKit's driver has no path for it yet; Android Views: Android has no switch for spell checking alone: its marks go with the suggestions, which `isTextPredictionEnabled` turns off. |
| `isTextPredictionEnabled` | property | `Bool` | native | · | ✅ | ✅ | ✅ | ✅ |  | cannot read isTextPredictionEnabled of TextField - AppKit's driver has no path for it yet |
| `maximumLength` | property | `Int` | native | ✅ | ✅ | ◐ | ✅ | ✅ |  | Android Views: cannot read maximumLength of TextField - Android's field keeps no bound of StateUI's: the host cuts what is typed, and typing proves it |
| `placeholder` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `placeholderColor` | property | `Color` | native | · | · | ✅ | ✅ | 🔌 |  | cannot read placeholderColor of TextField - AppKit's driver has no path for it yet; UIKit: cannot read placeholderColor of TextField - UIKit's driver has no path for it yet; GTK 4: only through the host's own: read placeholderColor of TextField: the class of the host's style sheet the widget wears: GTK reads back no placeholderColor |
| `selectionLength` | property | `Int` | native | · | ✅ | ✅ | ✅ | ✅ |  | cannot read selectionLength of TextField - AppKit's driver has no path for it yet |
| `onTextChanged` (`textChanged`) | event | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ | ✅ | ◐ | ✅ | ✅ |  | Android Views: waits on TextField.isReadOnly |
| `textCase` | property | `TextCase` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `textColor` | property | `Color` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive | – |  |  |  |  |  | macOS gives an application no text size of the user's to follow.; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native | ✅ | ✅ | · | ✅ | ✅ |  | Android Views: cannot read a family - Android's typeface keeps no family's name |
| `fontSize` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `verticalTextAlignment` | property | `TextAlignment` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
