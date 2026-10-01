<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

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
| AppKit | ✅ | 42 ✅ · 1 ☑️ | `NSTextField` / `NSSecureTextField` |  |
| UIKit | ✅ | 46 ✅ | `UITextField` |  |
| Android Views | ✅ | 66 ✅ · 1 ☑️ · 1 – | `EditText` |  |
| WinUI 3 | ✅ | 69 ✅ · 1 ☑️ | `TextBox` / `PasswordBox` |  |
| GTK 4 | ✅ | 24 ✅ | `GtkEntry` / `GtkPasswordEntry` |  |
| Web |  |  | `<input>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/TextFieldContract.swift`.

## TextField's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isPassword` | property | `Bool` | native | ✅ | ✅ | ✅ | ☑️ | · |  | WinUI 3: A PasswordBox has no read-only state, alignment, case, caret or selection: a password field keeps none of these.; GTK 4: cannot read isPassword of TextField - GTK's driver has no path for it yet |
| `returnKey` | property | `ReturnKey` | adaptive |  |  | · |  |  |  | not realized; UIKit: not realized; Android Views: cannot read returnKey of TextField - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `showsClearButton` | property | `Bool` | adaptive |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onSubmitted` (`submitted`) | event |  | native | ✅ | ✅ | ✅ | · | ✅ |  | WinUI 3: cannot submit on TextField - WinUI raises a text box's KeyDown only from the keyboard; Enter is walked on HelloWorld's field |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | · |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; GTK 4: cannot read accessibilityHeadingLevel of TextField - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityHint of TextField - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityLabel of TextField - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read automationExcludedWithChildren of TextField - GTK's driver has no path for it yet |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | ✅ | ✅ | ✅ | ✅ | ⏸ |  | GTK 4: waits on TextField.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read isAccessibilityHidden of TextField - GTK's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | ◐ | ✅ | ✅ |  | Android Views: waits on TextField.isReadOnly |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotX of TextField - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotY of TextField - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read rotation of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read rotation of TextField - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of TextField: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationX of TextField - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of TextField: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationY of TextField - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scale of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scale of TextField - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleX of TextField - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleY of TextField - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationX of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationX of TextField - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationY of TextField: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of TextField: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationY of TextField - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  | ✅ | ✅ | ✅ | ✅ | ⏸ |  | GTK 4: waits on TextField.isFocusedChanged, not realized yet |
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
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off.; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pinch on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pinch on TextField - GTK's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on TextField - GTK's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on TextField - GTK's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on TextField - GTK's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on TextField - GTK's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on TextField - GTK's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on TextField - GTK's driver has no path for it yet |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: tap on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot tap on TextField - GTK's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: tap on TextField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TextField: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot tap on TextField - GTK's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [InputView](tiers/InputView.md)

What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `cursorPosition` | property | `Int` | native | · | ✅ | ✅ | ✅ | · |  | cannot read cursorPosition of TextField - AppKit's driver has no path for it yet; GTK 4: cannot read cursorPosition of TextField - GTK's driver has no path for it yet |
| `inputPurpose` | property | `InputPurpose` | adaptive | 🔌 | ✅ | ✅ | ✅ | · |  | only through the host's own: read inputPurpose of TextField: the traits the host keeps; a Mac shows no keys a purpose picks; GTK 4: cannot read inputPurpose of TextField - GTK's driver has no path for it yet |
| `isReadOnly` | property | `Bool` | native | ✅ | ✅ |  | ✅ | ◐ |  | Android Views: not realized; GTK 4: cannot read isReadOnly of TextField - GTK's driver has no path for it yet |
| `isSpellCheckEnabled` | property | `Bool` | native | · | ✅ | – | ✅ | · |  | cannot read isSpellCheckEnabled of TextField - AppKit's driver has no path for it yet; Android Views: Android has no switch for spell checking alone: its marks go with the suggestions, which `isTextPredictionEnabled` turns off.; GTK 4: cannot read isSpellCheckEnabled of TextField - GTK's driver has no path for it yet |
| `isTextPredictionEnabled` | property | `Bool` | native | · | ✅ | ✅ | ✅ | · |  | cannot read isTextPredictionEnabled of TextField - AppKit's driver has no path for it yet; GTK 4: cannot read isTextPredictionEnabled of TextField - GTK's driver has no path for it yet |
| `maximumLength` | property | `Int` | native | ✅ | ✅ | ◐ | ✅ | ✅ |  | Android Views: cannot read maximumLength of TextField - Android's field keeps no bound of StateUI's: the host cuts what is typed, and typing proves it |
| `placeholder` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read placeholder of TextField - GTK's driver has no path for it yet |
| `placeholderColor` | property | `Color` | native | · | · | ✅ | ✅ | · |  | cannot read placeholderColor of TextField - AppKit's driver has no path for it yet; UIKit: cannot read placeholderColor of TextField - UIKit's driver has no path for it yet; GTK 4: cannot read placeholderColor of TextField - GTK's driver has no path for it yet |
| `selectionLength` | property | `Int` | native | · | ✅ | ✅ | ✅ | · |  | cannot read selectionLength of TextField - AppKit's driver has no path for it yet; GTK 4: cannot read selectionLength of TextField - GTK's driver has no path for it yet |
| `onTextChanged` (`textChanged`) | event | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ | ✅ | ◐ | ✅ | ◐ |  | Android Views: waits on TextField.isReadOnly; GTK 4: cannot read isPassword of TextField - GTK's driver has no path for it yet |
| `textCase` | property | `TextCase` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `textColor` | property | `Color` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read textColor of TextField - GTK's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read fontAttributes of TextField - GTK's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native | ✅ | ✅ | · | ✅ | · |  | Android Views: cannot read a family - Android's typeface keeps no family's name; GTK 4: cannot read fontFamily of TextField - GTK's driver has no path for it yet |
| `fontSize` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read fontSize of TextField - GTK's driver has no path for it yet |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read horizontalTextAlignment of TextField - GTK's driver has no path for it yet |
| `verticalTextAlignment` | property | `TextAlignment` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
