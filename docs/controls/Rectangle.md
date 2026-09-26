<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Rectangle

A rectangle, drawn as a shape - with square corners, or rounded ones.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Shape](tiers/Shape.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Shapes/RectangleContract.swift`.

## Rectangle's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `cornerRadius` | property | `CornerRadius` | native |  |  |  | ✅ | ✅ |  | cannot read the colour of Rectangle - AppKit's driver has no path for it yet |

Realization:

- **AppKit**: `NSView` drawing `NSBezierPath`
- **UIKit**: `UIView` drawing `UIBezierPath`
- **GTK 4**: `GskPath` in a snapshot
- **Android Views**: `View` drawing `Path`
- **WinUI 3**: `Microsoft.UI.Xaml.Shapes`
- **Web**: inline SVG

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityIdentifier of Rectangle - AppKit's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of Rectangle - AppKit's driver has no path for it yet; Android Views: cannot read a heading's level: Android marks a heading, not its level - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityHint of Rectangle - AppKit's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ | ✅ |  | cannot read accessibilityLabel of Rectangle - AppKit's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read automationExcludedWithChildren of Rectangle - AppKit's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  | ✅ |  |  | cannot read background of Rectangle - AppKit's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  | ✅ |  |  | ✅ | ✅ |  |  |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read isAccessibilityHidden of Rectangle - AppKit's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  | ✅ |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read pivotX of Rectangle - AppKit's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read pivotY of Rectangle - AppKit's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read rotation of Rectangle - AppKit's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  | ✅ |  |  | cannot read rotationX of Rectangle - AppKit's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  | ✅ |  |  | cannot read rotationY of Rectangle - AppKit's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scale of Rectangle - AppKit's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scaleX of Rectangle - AppKit's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read scaleY of Rectangle - AppKit's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read translationX of Rectangle - AppKit's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  | ✅ | ✅ |  | cannot read translationY of Rectangle - AppKit's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  | ✅ |  |  | ✅ | ✅ |  |  |
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
| `panTouchCount` | property | `Int` | structure | ☑️ |  |  | ✅ | ✅ |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `panXChannel` | property | `Int` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `panYChannel` | property | `Int` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `swipeThreshold` | property | `Double` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ |  |  | ✅ | ✅ |  |  |
| `tapCount` | property | `Int` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `onTapped` (`tapped`) | event |  | native | ✅ |  |  | ✅ | ✅ |  |  |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [Shape](tiers/Shape.md)

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native |  |  |  | ✅ | ✅ |  | cannot read aspect of Rectangle - AppKit's driver has no path for it yet |
| `fill` | property | `Brush` | stateUI |  |  |  | ✅ | ✅ |  | cannot read fill of Rectangle - AppKit's driver has no path for it yet |
| `renderTransform` | property | `ViewTransform` | native |  |  |  | ✅ | ✅ |  | cannot read renderTransform of Rectangle - AppKit's driver has no path for it yet |
| `stroke` | property | `Brush` | stateUI |  |  |  | ✅ | ✅ |  | cannot read stroke of Rectangle - AppKit's driver has no path for it yet |
| `strokeDashOffset` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeDashOffset of Rectangle - AppKit's driver has no path for it yet; Android Views: cannot read strokeDashOffset of Rectangle - Android's driver has no path for it yet |
| `strokeDashPattern` | property | `[Double]` | stateUI |  |  |  |  | ✅ |  | cannot read strokeDashPattern of Rectangle - AppKit's driver has no path for it yet; Android Views: cannot read strokeDashPattern of Rectangle - Android's driver has no path for it yet |
| `strokeLineCap` | property | `LineCap` | stateUI |  |  |  |  | ✅ |  | cannot read strokeLineCap of Rectangle - AppKit's driver has no path for it yet; Android Views: cannot read strokeLineCap of Rectangle - Android's driver has no path for it yet |
| `strokeLineJoin` | property | `LineJoin` | stateUI |  |  |  |  | ✅ |  | cannot read strokeLineJoin of Rectangle - AppKit's driver has no path for it yet; Android Views: cannot read strokeLineJoin of Rectangle - Android's driver has no path for it yet |
| `strokeMiterLimit` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeMiterLimit of Rectangle - AppKit's driver has no path for it yet; Android Views: cannot read strokeMiterLimit of Rectangle - Android's driver has no path for it yet |
| `strokeWidth` | property | `Double` | stateUI |  |  |  | ✅ | ✅ |  | cannot read strokeWidth of Rectangle - AppKit's driver has no path for it yet |
