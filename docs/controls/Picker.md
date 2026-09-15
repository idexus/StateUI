# Picker

One choice out of a list.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [TintElement](tiers/TintElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/Picker.swift`.

## Picker's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `isOpen` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onOpened` (`opened`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `options` | property | ✅ | ✅ |  |  |  |  |  |  |
| `selectedIndex` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onSelectedIndexChanged` (`selectedIndexChanged`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `title` | property | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `Picker`
- **AppKit**: `NSPopUpButton`
- **UIKit**: pop-up `UIButton` menu
- **GTK 4**: `GtkDropDown`
- **Android Views**: `Spinner`
- **WinUI 3**: `ComboBox`
- **Web**: `<select>`

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
| `isFocusedChanged` | handler | ✅ |  |  |  |  |  |  |  |
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
| `dragText` | property |  |  |  |  |  |  |  |  |
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

## From [TintElement](tiers/TintElement.md)

A control's accent: the colour the platform draws what is chosen, filled or under way in - a switch that is on, the covered part of a slider, a ticked box, the filled part of a bar, a spinner.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `tint` | property | ✅ | ✅ |  |  |  |  |  |  |
