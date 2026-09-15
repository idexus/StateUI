<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Ellipse

An oval filling the room it is given - a circle when that room is square.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Shape](tiers/Shape.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/EllipseContract.swift`.

## Ellipse's own members

Ellipse declares no members of its own.

Realization:

- **MAUI**: `Shape` over `RoundRectangle` / `Ellipse`
- **AppKit**: `NSView` drawing `NSBezierPath`
- **UIKit**: `UIView` drawing `UIBezierPath`
- **GTK 4**: `GskPath` in a snapshot
- **Android Views**: `View` drawing `Path`
- **WinUI 3**: `Microsoft.UI.Xaml.Shapes`
- **Web**: inline SVG

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ✅ | ✅ |  |  |  |  |  |  |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `background` | property | `Background` | native | ✅ | ✅* |  |  |  |  |  | AppKit paints a colour on this view; a brush is drawn only by `Border`. |
| `focus` | act | `() -> Bool` |  |  | ✅ |  |  |  |  |  |  |
| `frame` | property | `Rect` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `height` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isEnabled` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isVisible` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `layoutDirection` | property | `LayoutDirection` | native | ✅ |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `pivotX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `pivotY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `rotation` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `rotationX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `rotationY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `scale` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `scaleX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `scaleY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `translationY` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `unfocus` | act | `() -> Void` |  |  | ✅ |  |  |  |  |  |  |
| `onVisualStateChanged` (`visualStateChanged`) | event | `String` | stateUI | ✅ |  |  |  |  |  |  |  |
| `width` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `zIndex` | property | `Int` | native | ✅ |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `absoluteLayoutBounds` | property | `Rect` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `absoluteLayoutProportions` | property | `AbsoluteLayoutProportions` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `allowDrop` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `canDrag` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native | ✅ |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native | ✅ |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native | ✅ |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ |  |  |  |  |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ |  |  |  |  |  |  |
| `margin` | property | `Insets` | native | ✅ | ✅ |  |  |  |  |  |  |
| `panTouchCount` | property | `Int` | structure | ✅ | ✅* |  |  |  |  |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ | ✅ |  |  |  |  |  |  |
| `panXChannel` | property | `Int` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `panYChannel` | property | `Int` | structure | ✅ |  |  |  |  |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ | ✅ |  |  |  |  |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ | ✅ |  |  |  |  |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `swipeThreshold` | property | `Double` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ | ✅ |  |  |  |  |  |  |
| `tapCount` | property | `Int` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `onTapped` (`tapped`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [Shape](tiers/Shape.md)

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ✅ |  |  |  |  |  |  |  |
| `fill` | property | `Brush` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `renderTransform` | property | `ViewTransform` | native | ✅ |  |  |  |  |  |  |  |
| `stroke` | property | `Brush` | stateUI | ✅ | ✅* |  |  |  |  |  | AppKit strokes with a colour; a gradient brush draws no outline. |
| `strokeDashOffset` | property | `Double` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `strokeDashPattern` | property | `[Double]` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `strokeLineCap` | property | `LineCap` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `strokeLineJoin` | property | `LineJoin` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `strokeMiterLimit` | property | `Double` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
| `strokeWidth` | property | `Double` | stateUI | ✅ | ✅ |  |  |  |  |  |  |
