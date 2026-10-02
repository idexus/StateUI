<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# VStack

Stacks its children top to bottom, each as tall as it asks to be.

```swift
VStack {
    Label("One")
    Label("Two")
}
.spacing(12)
.padding(24)
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [StackBase](tiers/StackBase.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (74) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 30 ✅ · 25 ✓ · 3 – | custom `NSView` |  |
| UIKit | ✅ | 32 ✅ · 25 ✓ · 3 – | custom `UIView` |  |
| Android Views | ✅ | 52 ✅ · 1 ☑️ · 3 – | custom `ViewGroup` |  |
| WinUI 3 | ✅ | 56 ✅ · 3 – | `StackPanel` |  |
| GTK 4 | ✅ | 44 ✅ · 11 ✓ · 4 – | `GtkBox` |  |
| Web |  |  | flexbox | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Layouts/VStackContract.swift`.

## VStack's own members

VStack declares no members of its own.

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | – |  | GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code. |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | ✅ |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `background` | property | `Background` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read background of VStack - StateUI draws a layout's box on GTK's snapshot, which holds none of its background; its drawing proves it |
| `focus` | act | `() -> Bool` |  | – | – | – | – | – |  | VStack takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: VStack takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: VStack takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: VStack takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: VStack takes no keyboard focus here: it refuses it, and nothing is heard |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ | ✅ | · | ✅ | ✅ |  | Android Views: cannot read what reaches VStack - Android's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | – | – | – | – | – |  | VStack takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: VStack takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: VStack takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: VStack takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: VStack takes no keyboard focus here: it refuses it, and nothing is heard |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native | ✅ | ✅ |  |  |  |  | Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read pivotX of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotX of VStack: the host's own transform: GTK reads back no part of one |
| `pivotY` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read pivotY of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotY of VStack: the host's own transform: GTK reads back no part of one |
| `rotation` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read rotation of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotation of VStack: the host's own transform: GTK reads back no part of one |
| `rotationX` | property | `Double` | native | ✓ | ✓ | ✅ |  | ✓ |  | only through the host's own: read rotationX of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of VStack: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationX of VStack: the host's own transform: GTK reads back no part of one |
| `rotationY` | property | `Double` | native | ✓ | ✓ | ✅ |  | ✓ |  | only through the host's own: read rotationY of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of VStack: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationY of VStack: the host's own transform: GTK reads back no part of one |
| `scale` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read scale of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scale of VStack: the host's own transform: GTK reads back no part of one |
| `scaleX` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read scaleX of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleX of VStack: the host's own transform: GTK reads back no part of one |
| `scaleY` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read scaleY of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleY of VStack: the host's own transform: GTK reads back no part of one |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read translationX of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationX of VStack: the host's own transform: GTK reads back no part of one |
| `translationY` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read translationY of VStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of VStack: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationY of VStack: the host's own transform: GTK reads back no part of one |
| `unfocus` | act | `() -> Void` |  | – | – | – | – | – |  | VStack takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: VStack takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: VStack takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: VStack takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: VStack takes no keyboard focus here: it refuses it, and nothing is heard |
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
| `panTouchCount` | property | `Int` | structure | ✓ | ✓ | ☑️ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: pinch on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on VStack: the view's listening handed the recognizer's states, no touch sent; GTK 4: only through the host's own: pinch on VStack: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on VStack: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on VStack: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: tap on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on VStack: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: tap on VStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on VStack: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |  | · |  |  |  |  | not realized; UIKit: cannot read avoidsSafeArea of VStack - UIKit's view places its children where StateUI's layout says; their frames prove it; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `clipsContent` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `letsInputThrough` | property | `Bool` | native | ◐ | ◐ |  |  | ✅ |  | cannot read letsInputThrough of VStack - AppKit's driver has no path for it yet; UIKit: cannot read letsInputThrough of VStack - UIKit's driver has no path for it yet; Android Views: not realized; WinUI 3: not realized |

## From [StackBase](tiers/StackBase.md)

What both stacks have: the space between their children.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `spacing` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI | · | · | · | ✅ | · |  | cannot read shape of VStack - StateUI draws a layout's box in its view's draw(_:), which holds none of its shape; its drawing proves it; UIKit: cannot read shape of VStack - UIKit holds a layout's outline as its layer's path, no shape; its drawing proves it; Android Views: cannot read shape of VStack - StateUI draws a layout's box in a drawable of its own, which holds none of its shape; its drawing proves it; GTK 4: cannot read shape of VStack - StateUI draws a layout's box on GTK's snapshot, which holds none of its shape; its drawing proves it |
| `stroke` | property | `Brush` | stateUI |  | ✅ | · | ✅ | · |  | not realized; Android Views: cannot read stroke of VStack - StateUI draws a layout's box in a drawable of its own, which holds none of its stroke; its drawing proves it; GTK 4: cannot read stroke of VStack - StateUI draws a layout's box on GTK's snapshot, which holds none of its stroke; its drawing proves it |
| `strokeWidth` | property | `Double` | stateUI | · | ✅ | · | ✅ | · |  | cannot read strokeWidth of VStack - StateUI draws a layout's box in its view's draw(_:), which holds none of its strokeWidth; its drawing proves it; Android Views: cannot read strokeWidth of VStack - StateUI draws a layout's box in a drawable of its own, which holds none of its strokeWidth; its drawing proves it; GTK 4: cannot read strokeWidth of VStack - StateUI draws a layout's box on GTK's snapshot, which holds none of its strokeWidth; its drawing proves it |
