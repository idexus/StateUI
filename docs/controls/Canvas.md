<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Canvas

A canvas to draw on, one instruction at a time.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (70) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | custom `NSView` drawing | no run of it on these sources |
| UIKit |  |  | `UIView` `draw(_:)` | no run of it on these sources |
| Android Views |  |  | `View` `onDraw(Canvas)` | no run of it on these sources |
| WinUI 3 | ✅ | 52 ✅ · 3 – | Direct2D in a `SurfaceImageSource` |  |
| GTK 4 |  |  | `GtkDrawingArea` | not realized |
| Web |  |  | `<canvas>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Shapes/CanvasContract.swift`.

## Canvas's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onDragged` (`dragged`) | event | `Point` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `drawable` | property | `[DrawCommand]` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPressed` (`pressed`) | event | `Point` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onReleased` (`released`) | event | `Point` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  |  |  |  | – |  |  | WinUI 3: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `frame` | property | `Rect` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `height` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | – |  |  | WinUI 3: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `opacity` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `pivotX` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `pivotY` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `rotation` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `scale` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `scaleX` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `scaleY` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `style` | property | `Name` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `translationX` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `translationY` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `unfocus` | act | `() -> Void` |  |  |  |  | – |  |  | WinUI 3: Canvas takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `width` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridColumn` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridColumnSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridRow` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridRowSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `horizontalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `margin` | property | `Insets` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `panTouchCount` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `panXChannel` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `panYChannel` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `swipeThreshold` | property | `Double` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `tapCount` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onTapped` (`tapped`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
