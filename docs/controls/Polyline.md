<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Polyline

An open outline through a list of points - a chart line, a signature, a zigzag.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Shape](tiers/Shape.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (78) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 26 ✅ · 1 ☑️ | `NSView` drawing `NSBezierPath` |  |
| UIKit | ✅ | 25 ✅ | `UIView` drawing `UIBezierPath` |  |
| Android Views | ✅ | 51 ✅ | `View` drawing `Path` |  |
| WinUI 3 | ⌛ |  | `Microsoft.UI.Xaml.Shapes` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GskPath` in a snapshot | no run of it on these sources |
| Web |  |  | inline SVG | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Shapes/PolylineContract.swift`.

## Polyline's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fillRule` | property | `FillRule` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `points` | property | `[Point]` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ⌛ |  |  | cannot read a heading's level: AppKit marks a heading, not its level - AppKit's driver has no path for it yet; UIKit: cannot read a heading's level: UIKit marks a heading, not its level - UIKit's driver has no path for it yet; Android Views: cannot read a heading's level: Android marks a heading, not its level - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `background` | property | `Background` | native | ☑️ |  | ✅ | ⌛ |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: a run of other sources said: not realized |
| `focus` | act | `() -> Bool` |  | · | · | · | ⌛ |  |  | cannot focus Polyline: it takes no keyboard focus here; UIKit: cannot focus Polyline: it takes no keyboard focus here; Android Views: cannot focus Polyline: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native |  | · |  | ⌛ |  |  | not realized; UIKit: cannot read isEnabled of Polyline - UIKit's driver has no path for it yet; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isFocusedChanged` | event | `Bool` | native | · | · | · | ⌛ |  |  | cannot focus Polyline: it takes no keyboard focus here; UIKit: cannot focus Polyline: it takes no keyboard focus here; Android Views: cannot focus Polyline: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read pivotX of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read pivotY of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotation of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotationX of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotationY of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: not realized |
| `scale` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scale of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scaleX of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scaleY of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `style` | property | `Name` | structure |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `translationX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read translationX of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read translationY of Polyline: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of Polyline: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | · | · | · | ⌛ |  |  | cannot focus Polyline: it takes no keyboard focus here; UIKit: cannot focus Polyline: it takes no keyboard focus here; Android Views: cannot focus Polyline: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `width` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `zIndex` | property | `Int` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `canDrag` | property | `Bool` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `dragStarting` | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `dragText` | property | `String` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `panTouchCount` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pinch on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: tap on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: tap on Polyline: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Polyline: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [Shape](tiers/Shape.md)

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read aspect of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read aspect of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read aspect of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `fill` | property | `Brush` | stateUI | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read fill of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read fill of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read fill of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `renderTransform` | property | `ViewTransform` | native | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read renderTransform of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read renderTransform of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read renderTransform of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `stroke` | property | `Brush` | stateUI | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read stroke of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read stroke of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read stroke of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeDashOffset` | property | `Double` | stateUI | · | · | · | ⌛ |  |  | cannot read strokeDashOffset of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read strokeDashOffset of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read strokeDashOffset of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeDashPattern` | property | `[Double]` | stateUI | · | · | · | ⌛ |  |  | cannot read strokeDashPattern of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read strokeDashPattern of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read strokeDashPattern of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeLineCap` | property | `LineCap` | stateUI | · | · | · | ⌛ |  |  | cannot read strokeLineCap of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read strokeLineCap of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read strokeLineCap of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeLineJoin` | property | `LineJoin` | stateUI | · | · | · | ⌛ |  |  | cannot read strokeLineJoin of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read strokeLineJoin of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read strokeLineJoin of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeMiterLimit` | property | `Double` | stateUI | · | · | · | ⌛ |  |  | cannot read strokeMiterLimit of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read strokeMiterLimit of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read strokeMiterLimit of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeWidth` | property | `Double` | stateUI | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read strokeWidth of Polyline - AppKit's driver has no path for it yet; UIKit: cannot read strokeWidth of Polyline - UIKit's driver has no path for it yet; Android Views: cannot read strokeWidth of Polyline - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
