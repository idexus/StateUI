# RadioButton

One choice out of several, where picking one clears the rest.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/RadioButton.swift`.

## RadioButton's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `groupName` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isOn` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onToggled` (`toggled`) | handler | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `RadioButton`
- **AppKit**: `NSButton` radio
- **UIKit**: composed by StateUI
- **GTK 4**: grouped `GtkCheckButton`
- **Android Views**: `RadioButton`
- **WinUI 3**: `RadioButton`
- **Web**: `<input type=radio>`

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

## From [TextElement](tiers/TextElement.md)

The tier for a control whose text IS a property: everything `TextStyleElement` has, plus the text itself.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | ✅ | ✅ |  |  |  |  |  |  |
| `textCase` | property | ✅ | ✅ |  |  |  |  |  |  |

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

## From [PaddingElement](tiers/PaddingElement.md)

The space a control keeps INSIDE itself, around its content.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | ✅ | ✅ |  |  |  |  |  |  |

## From [BorderElement](tiers/BorderElement.md)

The outline of a control that draws one - the tier `Button` and `RadioButton` wear, and the one place the three properties that paint an outline are declared.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `borderColor` | property | ✅ |  |  |  |  |  |  |  |
| `borderWidth` | property | ✅ |  |  |  |  |  |  |  |
| `cornerRadius` | property | ✅ |  |  |  |  |  |  |  |
