<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Line

A straight line between two points, in device units from the top left of the space the line is given.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Shape](tiers/Shape.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Shapes/LineContract.swift`.

## Line's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `x1` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read the colour of Line - AppKit's driver has no path for it yet; Android Views: cannot read the colour of Line - Android's driver has no path for it yet |
| `x2` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read the colour of Line - AppKit's driver has no path for it yet; Android Views: cannot read the colour of Line - Android's driver has no path for it yet |
| `y1` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read the colour of Line - AppKit's driver has no path for it yet; Android Views: cannot read the colour of Line - Android's driver has no path for it yet |
| `y2` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read the colour of Line - AppKit's driver has no path for it yet; Android Views: cannot read the colour of Line - Android's driver has no path for it yet |

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
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of Line - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of Line - Android's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of Line - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHeadingLevel of Line - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityHint of Line - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHint of Line - Android's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityLabel of Line - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityLabel of Line - Android's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read automationExcludedWithChildren of Line - AppKit's driver has no path for it yet; Android Views: cannot read automationExcludedWithChildren of Line - Android's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  |  |  | cannot read background of Line - AppKit's driver has no path for it yet; Android Views: cannot read background of Line - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of Line - AppKit's driver has no path for it yet |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | cannot read what reaches Line - AppKit's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isAccessibilityHidden of Line - AppKit's driver has no path for it yet; Android Views: cannot read isAccessibilityHidden of Line - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  | ✅ |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read the focus of Line - AppKit's driver has no path for it yet |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotX of Line - AppKit's driver has no path for it yet; Android Views: cannot read pivotX of Line - Android's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotY of Line - AppKit's driver has no path for it yet; Android Views: cannot read pivotY of Line - Android's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read rotation of Line - AppKit's driver has no path for it yet; Android Views: cannot read rotation of Line - Android's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationX of Line - AppKit's driver has no path for it yet; Android Views: cannot read rotationX of Line - Android's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationY of Line - AppKit's driver has no path for it yet; Android Views: cannot read rotationY of Line - Android's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scale of Line - AppKit's driver has no path for it yet; Android Views: cannot read scale of Line - Android's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleX of Line - AppKit's driver has no path for it yet; Android Views: cannot read scaleX of Line - Android's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleY of Line - AppKit's driver has no path for it yet; Android Views: cannot read scaleY of Line - Android's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationX of Line - AppKit's driver has no path for it yet; Android Views: cannot read translationX of Line - Android's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationY of Line - AppKit's driver has no path for it yet; Android Views: cannot read translationY of Line - Android's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of Line - AppKit's driver has no path for it yet |
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
| `panTouchCount` | property | `Int` | structure | ☑️ |  |  |  | ✅ |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off.; Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot pinch on Line - Android's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on Line - Android's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on Line - Android's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on Line - Android's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on Line - Android's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on Line - Android's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on Line - Android's driver has no path for it yet |
| `tapCount` | property | `Int` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot tap on Line - Android's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native | ✅ |  |  |  | ✅ |  | Android Views: cannot tap on Line - Android's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [Shape](tiers/Shape.md)

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native |  |  |  |  | ✅ |  | cannot read aspect of Line - AppKit's driver has no path for it yet; Android Views: cannot read aspect of Line - Android's driver has no path for it yet |
| `fill` | property | `Brush` | stateUI |  |  |  |  | ✅ |  | cannot read fill of Line - AppKit's driver has no path for it yet; Android Views: cannot read fill of Line - Android's driver has no path for it yet |
| `renderTransform` | property | `ViewTransform` | native |  |  |  |  | ✅ |  | cannot read renderTransform of Line - AppKit's driver has no path for it yet; Android Views: cannot read renderTransform of Line - Android's driver has no path for it yet |
| `stroke` | property | `Brush` | stateUI |  |  |  |  | ✅ |  | cannot read stroke of Line - AppKit's driver has no path for it yet; Android Views: cannot read stroke of Line - Android's driver has no path for it yet |
| `strokeDashOffset` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeDashOffset of Line - AppKit's driver has no path for it yet; Android Views: cannot read strokeDashOffset of Line - Android's driver has no path for it yet |
| `strokeDashPattern` | property | `[Double]` | stateUI |  |  |  |  | ✅ |  | cannot read strokeDashPattern of Line - AppKit's driver has no path for it yet; Android Views: cannot read strokeDashPattern of Line - Android's driver has no path for it yet |
| `strokeLineCap` | property | `LineCap` | stateUI |  |  |  |  | ✅ |  | cannot read strokeLineCap of Line - AppKit's driver has no path for it yet; Android Views: cannot read strokeLineCap of Line - Android's driver has no path for it yet |
| `strokeLineJoin` | property | `LineJoin` | stateUI |  |  |  |  | ✅ |  | cannot read strokeLineJoin of Line - AppKit's driver has no path for it yet; Android Views: cannot read strokeLineJoin of Line - Android's driver has no path for it yet |
| `strokeMiterLimit` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeMiterLimit of Line - AppKit's driver has no path for it yet; Android Views: cannot read strokeMiterLimit of Line - Android's driver has no path for it yet |
| `strokeWidth` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeWidth of Line - AppKit's driver has no path for it yet; Android Views: cannot read strokeWidth of Line - Android's driver has no path for it yet |
