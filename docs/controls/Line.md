<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Line

A straight line between two points, in device units from the top left of the space the line is given.

```swift
Line()
    .x1(0).y1(0)
    .x2(240).y2(0)
    .stroke(.lightGray)
    .strokeWidth(1)
```

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Shape](tiers/Shape.md)

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

| Host | Created | Members (80) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 29 ✅ · 1 ☑️ · 3 – | `NSView` drawing `NSBezierPath` |  |
| UIKit | ✅ | 30 ✅ · 3 – | `UIView` drawing `UIBezierPath` |  |
| Android Views | ✅ | 53 ✅ · 1 ☑️ · 3 – | `View` drawing `Path` |  |
| WinUI 3 | ✅ | 62 ✅ · 3 – | `Microsoft.UI.Xaml.Shapes` |  |
| GTK 4 | ✅ | 48 ✅ · 3 – | `GskPath` in a snapshot |  |
| Web |  |  | inline SVG | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Shapes/LineContract.swift`.

## Line's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `x1` | property | `Double` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `x2` | property | `Double` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `y1` | property | `Double` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `y2` | property | `Double` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | ✅ |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | – | – | – | – | – |  | Line takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Line takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Line takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Line takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: Line takes no keyboard focus here: it refuses it, and nothing is heard |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | – | – | – | – | – |  | Line takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Line takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Line takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Line takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: Line takes no keyboard focus here: it refuses it, and nothing is heard |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read pivotX of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotX of Line: the host's own transform: GTK reads back no part of one |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read pivotY of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotY of Line: the host's own transform: GTK reads back no part of one |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read rotation of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotation of Line: the host's own transform: GTK reads back no part of one |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | 🔌 |  | only through the host's own: read rotationX of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of Line: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationX of Line: the host's own transform: GTK reads back no part of one |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | 🔌 |  | only through the host's own: read rotationY of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of Line: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationY of Line: the host's own transform: GTK reads back no part of one |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read scale of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scale of Line: the host's own transform: GTK reads back no part of one |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read scaleX of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleX of Line: the host's own transform: GTK reads back no part of one |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read scaleY of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleY of Line: the host's own transform: GTK reads back no part of one |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read translationX of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationX of Line: the host's own transform: GTK reads back no part of one |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: read translationY of Line: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of Line: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationY of Line: the host's own transform: GTK reads back no part of one |
| `unfocus` | act | `() -> Void` |  | – | – | – | – | – |  | Line takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Line takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Line takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Line takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: Line takes no keyboard focus here: it refuses it, and nothing is heard |
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
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: pinch on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on Line: the view's listening handed the recognizer's states, no touch sent; GTK 4: only through the host's own: pinch on Line: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Line: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Line: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Line: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on Line: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Line: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [Shape](tiers/Shape.md)

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ◐ | ◐ | ◐ | ✅ | ✅ |  | cannot read aspect of Line - StateUI draws a shape in its view's draw(_:), which holds none of its aspect; its drawing proves it; UIKit: cannot read aspect of Line - StateUI places and moves a shape's figure into its layer's path, which holds no aspect; its drawing proves it; Android Views: cannot read aspect of Line - StateUI draws a shape in its view's onDraw, which holds none of its aspect; its drawing proves it |
| `fill` | property | `Brush` | stateUI | ◐ | ✅ | ◐ | ✅ | ✅ |  | cannot read fill of Line - StateUI draws a shape in its view's draw(_:), which holds none of its fill; its drawing proves it; Android Views: cannot read fill of Line - StateUI draws a shape in its view's onDraw, which holds none of its fill; its drawing proves it |
| `renderTransform` | property | `ViewTransform` | native | ◐ | ◐ | ◐ | ✅ | ✅ |  | cannot read renderTransform of Line - StateUI draws a shape in its view's draw(_:), which holds none of its renderTransform; its drawing proves it; UIKit: cannot read renderTransform of Line - StateUI places and moves a shape's figure into its layer's path, which holds no renderTransform; its drawing proves it; Android Views: cannot read renderTransform of Line - StateUI draws a shape in its view's onDraw, which holds none of its renderTransform; its drawing proves it |
| `stroke` | property | `Brush` | stateUI | ◐ | ✅ | ◐ | ✅ | ✅ |  | cannot read stroke of Line - StateUI draws a shape in its view's draw(_:), which holds none of its stroke; its drawing proves it; Android Views: cannot read stroke of Line - StateUI draws a shape in its view's onDraw, which holds none of its stroke; its drawing proves it |
| `strokeDashOffset` | property | `Double` | stateUI | · | · | · | ✅ | · |  | cannot read strokeDashOffset of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeDashOffset; its drawing proves it; UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line; Android Views: cannot read strokeDashOffset of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeDashOffset; its drawing proves it; GTK 4: cannot read strokeDashOffset of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeDashOffset; its drawing proves it |
| `strokeDashPattern` | property | `[Double]` | stateUI | · | · | · | ✅ | · |  | cannot read strokeDashPattern of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeDashPattern; its drawing proves it; UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line; Android Views: cannot read strokeDashPattern of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeDashPattern; its drawing proves it; GTK 4: cannot read strokeDashPattern of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeDashPattern; its drawing proves it |
| `strokeLineCap` | property | `LineCap` | stateUI | · | · | · | ✅ | · |  | cannot read strokeLineCap of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeLineCap; its drawing proves it; UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line; Android Views: cannot read strokeLineCap of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeLineCap; its drawing proves it; GTK 4: cannot read strokeLineCap of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeLineCap; its drawing proves it |
| `strokeLineJoin` | property | `LineJoin` | stateUI | · | · | · | ✅ | · |  | cannot read strokeLineJoin of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeLineJoin; its drawing proves it; UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line; Android Views: cannot read strokeLineJoin of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeLineJoin; its drawing proves it; GTK 4: cannot read strokeLineJoin of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeLineJoin; its drawing proves it |
| `strokeMiterLimit` | property | `Double` | stateUI | · | · | · | ✅ | · |  | cannot read strokeMiterLimit of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeMiterLimit; its drawing proves it; UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line; Android Views: cannot read strokeMiterLimit of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeMiterLimit; its drawing proves it; GTK 4: cannot read strokeMiterLimit of Line - StateUI draws a shape on GTK's snapshot, which holds none of its strokeMiterLimit; its drawing proves it |
| `strokeWidth` | property | `Double` | stateUI | ◐ | ◐ | ◐ | ✅ | ✅ |  | cannot read strokeWidth of Line - StateUI draws a shape in its view's draw(_:), which holds none of its strokeWidth; its drawing proves it; UIKit: cannot read the line of a shape drawing no outline - UIKit draws no outline for a shape given no stroke, and holds none of its line; Android Views: cannot read strokeWidth of Line - StateUI draws a shape in its view's onDraw, which holds none of its strokeWidth; its drawing proves it |
