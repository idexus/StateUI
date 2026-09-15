# TextField

A native single-line text field.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [InputView](tiers/InputView.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/TextField.swift`.

## TextField's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isPassword` | property | ✅ | ✅ |  |  |  |  |  |  |
| `returnKey` | property | ✅ |  |  |  |  |  |  |  |
| `showsClearButton` | property | ✅ |  |  |  |  |  |  |  |
| `onSubmitted` (`submitted`) | handler | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `Entry`
- **AppKit**: `NSTextField` / `NSSecureTextField`
- **UIKit**: `UITextField`
- **GTK 4**: `GtkEntry` / `GtkPasswordEntry`
- **Android Views**: `EditText`
- **WinUI 3**: `TextBox` / `PasswordBox`
- **Web**: `<input>`

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | ✅ | ✅ |  |  |  |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

A control backed by a node, and drawn.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | ✅ | ✅ |  |  |  |  |  |  |
| `accessibilityHint` | property | ✅ | ✅ |  |  |  |  |  |  |
| `accessibilityLabel` | property | ✅ | ✅ |  |  |  |  |  |  |
| `automationExcludedWithChildren` | property | ✅ | ✅ |  |  |  |  |  |  |
| `background` | property | ✅ | ✅* |  |  |  |  |  | AppKit paints a colour on this view; a brush is drawn only by `Border`. |
| `frame` | property | ✅ | ✅ |  |  |  |  |  |  |
| `height` | property | ✅ | ✅ |  |  |  |  |  |  |
| `ignoresInput` | property | ✅ |  |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isEnabled` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isFocusedChanged` | handler | ✅ | ✅ |  |  |  |  |  |  |
| `isVisible` | property | ✅ | ✅ |  |  |  |  |  |  |
| `layoutDirection` | property | ✅ |  |  |  |  |  |  |  |
| `maximumHeight` | property | ✅ | ✅ |  |  |  |  |  |  |
| `maximumWidth` | property | ✅ | ✅ |  |  |  |  |  |  |
| `minimumHeight` | property | ✅ | ✅ |  |  |  |  |  |  |
| `minimumWidth` | property | ✅ | ✅ |  |  |  |  |  |  |
| `opacity` | property | ✅ | ✅ |  |  |  |  |  |  |
| `pivotX` | property | ✅ | ✅ |  |  |  |  |  |  |
| `pivotY` | property | ✅ | ✅ |  |  |  |  |  |  |
| `rotation` | property | ✅ | ✅ |  |  |  |  |  |  |
| `rotationX` | property | ✅ | ✅ |  |  |  |  |  |  |
| `rotationY` | property | ✅ | ✅ |  |  |  |  |  |  |
| `scale` | property | ✅ | ✅ |  |  |  |  |  |  |
| `scaleX` | property | ✅ | ✅ |  |  |  |  |  |  |
| `scaleY` | property | ✅ | ✅ |  |  |  |  |  |  |
| `style` | property |  |  |  |  |  |  |  |  |
| `translationX` | property | ✅ | ✅ |  |  |  |  |  |  |
| `translationY` | property | ✅ | ✅ |  |  |  |  |  |  |
| `width` | property | ✅ | ✅ |  |  |  |  |  |  |
| `zIndex` | property | ✅ |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

A VisualElement a layout positions.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `absoluteLayoutBounds` | property | ✅ | ✅ |  |  |  |  |  |  |
| `absoluteLayoutProportions` | property | ✅ | ✅ |  |  |  |  |  |  |
| `allowDrop` | property | ✅ |  |  |  |  |  |  |  |
| `canDrag` | property | ✅ |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | handler | ✅ |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | handler | ✅ |  |  |  |  |  |  |  |
| `dragStarting` | handler | ✅ |  |  |  |  |  |  |  |
| `dragText` | property | ✅ |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | handler | ✅ |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | handler | ✅ |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `gridColumn` | property | ✅ | ✅ |  |  |  |  |  |  |
| `gridColumnSpan` | property | ✅ | ✅ |  |  |  |  |  |  |
| `gridRow` | property | ✅ | ✅ |  |  |  |  |  |  |
| `gridRowSpan` | property | ✅ | ✅ |  |  |  |  |  |  |
| `horizontalAlignment` | property | ✅ | ✅ |  |  |  |  |  |  |
| `margin` | property | ✅ | ✅ |  |  |  |  |  |  |
| `panTouchCount` | property | ✅ | ✅* |  |  |  |  |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerEntered` (`pointerEntered`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerExited` (`pointerExited`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerMoved` (`pointerMoved`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerPressed` (`pointerPressed`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerReleased` (`pointerReleased`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `swipeDirection` | property | ✅ | ✅ |  |  |  |  |  |  |
| `swipeThreshold` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onSwiped` (`swiped`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `tapCount` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onTapped` (`tapped`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `verticalAlignment` | property | ✅ | ✅ |  |  |  |  |  |  |

## From [InputView](tiers/InputView.md)

A View the reader types into.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `cursorPosition` | property | ✅ | ✅ |  |  |  |  |  |  |
| `inputPurpose` | property | ✅ |  |  |  |  |  |  |  |
| `isReadOnly` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isSpellCheckEnabled` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isTextPredictionEnabled` | property | ✅ | ✅ |  |  |  |  |  |  |
| `maximumLength` | property | ✅ | ✅ |  |  |  |  |  |  |
| `placeholder` | property | ✅ | ✅ |  |  |  |  |  |  |
| `placeholderColor` | property | ✅ | ✅ |  |  |  |  |  |  |
| `selectionLength` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onTextChanged` (`textChanged`) | handler | ✅ | ✅ |  |  |  |  |  |  |

## From [TextElement](tiers/TextElement.md)

The tier for a control whose text IS a property: everything `TextStyleElement` has, plus the text itself.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | ✅ | ✅ |  |  |  |  |  |  |
| `textCase` | property | ✅ |  |  |  |  |  |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

The colour and letter spacing of a control's text, WITHOUT the text itself.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | ✅ |  |  |  |  |  |  |  |
| `textColor` | property | ✅ | ✅ |  |  |  |  |  |  |

## From [FontElement](tiers/FontElement.md)

How the text of a control is set in type - its size, its family, its weight.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | ✅ | ✅ |  |  |  |  |  |  |
| `fontAutoScalingEnabled` | property | ✅ |  |  |  |  |  |  |  |
| `fontFamily` | property | ✅ | ✅ |  |  |  |  |  |  |
| `fontSize` | property | ✅ | ✅ |  |  |  |  |  |  |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where a control's text sits INSIDE the control.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | ✅ | ✅ |  |  |  |  |  |  |
| `verticalTextAlignment` | property | ✅ |  |  |  |  |  |  |  |
