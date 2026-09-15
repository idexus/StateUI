# ScrollView

A scrollable container.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [PaddingElement](tiers/PaddingElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/ScrollView.swift`.

## ScrollView's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalScrollBarVisibility` | property | ✅ | ✅ |  |  |  |  |  |  |
| `orientation` | property | ✅ | ✅ |  |  |  |  |  |  |
| `onScrollStopped` (`scrollStopped`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `verticalScrollBarVisibility` | property | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `ScrollView`
- **AppKit**: `NSScrollView`
- **UIKit**: `UIScrollView`
- **GTK 4**: `GtkScrolledWindow`
- **Android Views**: `ScrollView` / `HorizontalScrollView`
- **WinUI 3**: `ScrollViewer`
- **Web**: `overflow: auto`

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
| `isEnabled` | property | ✅ |  |  |  |  |  |  |  |
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

## From [PaddingElement](tiers/PaddingElement.md)

The space a control keeps INSIDE itself, around its content.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | ✅ | ✅ |  |  |  |  |  |  |
