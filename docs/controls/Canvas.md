<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Canvas

A canvas to draw on, one instruction at a time.

```swift
@State var dot = Point(40, 40)

Canvas {
    Draw.fillColor(.cornflowerBlue)
    Draw.fillEllipse(x: dot.x - 8, y: dot.y - 8, width: 16, height: 16)
}
.height(120)
.onPressed { point in dot = point }
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

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

| Host | Created | Members (70) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 26 ✅ · 1 ☑️ · 3 – | custom `NSView` drawing |  |
| UIKit | ✅ | 25 ✅ · 3 – | `UIView` `draw(_:)` |  |
| Android Views | ✅ | 53 ✅ · 1 ☑️ · 3 – | `View` `onDraw(Canvas)` |  |
| WinUI 3 | ✅ | 52 ✅ · 3 – | Direct2D in a `SurfaceImageSource` |  |
| GTK 4 |  |  | `GtkDrawingArea` | not realized |
| Web |  |  | `<canvas>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Shapes/CanvasContract.swift`.

## Canvas's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onDragged` (`dragged`) | event | `Point` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pressDown on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pressDown on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `drawable` | property | `[DrawCommand]` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `onPressed` (`pressed`) | event | `Point` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pressDown on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pressDown on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onReleased` (`released`) | event | `Point` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pressDown on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pressDown on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ |  |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; GTK 4: not realized |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | – | – | – | – |  |  | Canvas takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isFocusedChanged` | event | `Bool` | native | – | – | – | – |  |  | Canvas takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read pivotX of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read pivotY of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read rotation of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  |  |  | only through the host's own: read rotationX of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of Canvas: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  |  |  | only through the host's own: read rotationY of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of Canvas: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read scale of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read scaleX of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read scaleY of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read translationX of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read translationY of Canvas: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of Canvas: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `unfocus` | act | `() -> Void` |  | – | – | – | – |  |  | Canvas takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `width` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off.; GTK 4: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pinch on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: tap on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: tap on Canvas: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Canvas: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
