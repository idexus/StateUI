# TitleBar

An authored title area attached to a window through `WindowSession`.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/TitleBar.swift`.

## TitleBar's own members

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barForegroundColor` | property | ✅ |  |  |  |  |  |  |
| `icon` | property | ✅ |  |  |  |  |  |  |
| `subtitle` | property | ✅ |  |  |  |  |  |  |

Realization:

- **AppKit**: slots in `NSToolbar`; title in a trailing `NSTitlebarAccessoryViewController`
- **UIKit**: no native counterpart is named yet.
- **GTK 4**: `GtkHeaderBar`
- **Android Views**: no native counterpart is named yet.
- **WinUI 3**: `TitleBar`
- **Web**: no native counterpart is named yet.

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | ✅ |  |  |  |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

A control backed by a node, and drawn.

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | ✅ |  |  |  |  |  |  |
| `accessibilityHint` | property | ✅ |  |  |  |  |  |  |
| `accessibilityLabel` | property | ✅ |  |  |  |  |  |  |
| `automationExcludedWithChildren` | property | ✅ |  |  |  |  |  |  |
| `background` | property | ✅* |  |  |  |  |  | AppKit paints a colour on this view; a brush is drawn only by `Border`. |
| `frame` | property | ✅ |  |  |  |  |  |  |
| `height` | property |  |  |  |  |  |  |  |
| `ignoresInput` | property |  |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | ✅ |  |  |  |  |  |  |
| `isEnabled` | property |  |  |  |  |  |  |  |
| `isFocusedChanged` | handler |  |  |  |  |  |  |  |
| `isVisible` | property |  |  |  |  |  |  |  |
| `layoutDirection` | property |  |  |  |  |  |  |  |
| `maximumHeight` | property |  |  |  |  |  |  |  |
| `maximumWidth` | property |  |  |  |  |  |  |  |
| `minimumHeight` | property |  |  |  |  |  |  |  |
| `minimumWidth` | property |  |  |  |  |  |  |  |
| `opacity` | property |  |  |  |  |  |  |  |
| `pivotX` | property |  |  |  |  |  |  |  |
| `pivotY` | property |  |  |  |  |  |  |  |
| `rotation` | property |  |  |  |  |  |  |  |
| `rotationX` | property |  |  |  |  |  |  |  |
| `rotationY` | property |  |  |  |  |  |  |  |
| `scale` | property |  |  |  |  |  |  |  |
| `scaleX` | property |  |  |  |  |  |  |  |
| `scaleY` | property |  |  |  |  |  |  |  |
| `style` | property |  |  |  |  |  |  |  |
| `translationX` | property |  |  |  |  |  |  |  |
| `translationY` | property |  |  |  |  |  |  |  |
| `width` | property |  |  |  |  |  |  |  |
| `zIndex` | property |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

A VisualElement a layout positions.

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `absoluteLayoutBounds` | property |  |  |  |  |  |  |  |
| `absoluteLayoutProportions` | property |  |  |  |  |  |  |  |
| `allowDrop` | property |  |  |  |  |  |  |  |
| `canDrag` | property |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | handler |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | handler |  |  |  |  |  |  |  |
| `dragStarting` | handler |  |  |  |  |  |  |  |
| `dragText` | property |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | handler |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | handler |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | handler | ✅ |  |  |  |  |  |  |
| `gridColumn` | property |  |  |  |  |  |  |  |
| `gridColumnSpan` | property |  |  |  |  |  |  |  |
| `gridRow` | property |  |  |  |  |  |  |  |
| `gridRowSpan` | property |  |  |  |  |  |  |  |
| `horizontalAlignment` | property |  |  |  |  |  |  |  |
| `margin` | property |  |  |  |  |  |  |  |
| `panTouchCount` | property | ✅ |  |  |  |  |  |  |
| `onPanUpdated` (`panUpdated`) | handler | ✅ |  |  |  |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | handler | ✅ |  |  |  |  |  |  |
| `onPointerEntered` (`pointerEntered`) | handler | ✅ |  |  |  |  |  |  |
| `onPointerExited` (`pointerExited`) | handler | ✅ |  |  |  |  |  |  |
| `onPointerMoved` (`pointerMoved`) | handler | ✅ |  |  |  |  |  |  |
| `onPointerPressed` (`pointerPressed`) | handler | ✅ |  |  |  |  |  |  |
| `onPointerReleased` (`pointerReleased`) | handler | ✅ |  |  |  |  |  |  |
| `swipeDirection` | property | ✅ |  |  |  |  |  |  |
| `swipeThreshold` | property | ✅ |  |  |  |  |  |  |
| `onSwiped` (`swiped`) | handler | ✅ |  |  |  |  |  |  |
| `tapCount` | property | ✅ |  |  |  |  |  |  |
| `onTapped` (`tapped`) | handler | ✅ |  |  |  |  |  |  |
| `verticalAlignment` | property |  |  |  |  |  |  |  |
