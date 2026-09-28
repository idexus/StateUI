<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Grid

Arranges its children in rows and columns.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (77) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | custom `NSView` | a run of other sources said: ✅ |
| UIKit | ⌛ |  | composed by StateUI | a run of other sources said: ✅ |
| Android Views | ⌛ |  | composed by StateUI | a run of other sources said: ✅ |
| WinUI 3 | ✅ | 58 ✅ | composed by StateUI |  |
| GTK 4 |  |  | composed by StateUI | no run of it on these sources |
| Web |  |  | composed by StateUI | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/GridContract.swift`.

## Grid's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `columnSpacing` | property | `Double` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `columns` | property | `[GridLength]` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `rowSpacing` | property | `Double` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `rows` | property | `[GridLength]` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read a heading's level - AppKit marks a heading, not its level; UIKit: a run of other sources said: · cannot read a heading's level - UIKit marks a heading, not its level; Android Views: a run of other sources said: · cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `accessibilityLabel` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `automationExcludedWithChildren` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `background` | property | `Background` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: · cannot read background of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ✅ |
| `focus` | act | `() -> Bool` |  | ⌛ | ⌛ | ⌛ | · |  |  | a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; UIKit: a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; WinUI 3: cannot focus Grid: it takes no keyboard focus here |
| `frame` | property | `Rect` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read what reaches Grid - Android's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | ⌛ | ⌛ | ⌛ | · |  |  | a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; UIKit: a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; WinUI 3: cannot focus Grid: it takes no keyboard focus here |
| `isVisible` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read pivotX of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotX of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read pivotY of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotY of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read rotation of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotation of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationX of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationX of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `rotationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationY of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationY of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `scale` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scale of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scale of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scaleX of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleX of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scaleY of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleY of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `style` | property | `Name` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `translationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read translationX of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationX of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read translationY of Grid: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationY of Grid: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | ⌛ | ⌛ | ⌛ | · |  |  | a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; UIKit: a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus Grid: it takes no keyboard focus here; WinUI 3: cannot focus Grid: it takes no keyboard focus here |
| `width` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `zIndex` | property | `Int` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `area` | property | `Area` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `canDrag` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDragOver` (`dragOver`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `dragStarting` | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `dragText` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDrop` (`drop`) | event | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `gridColumn` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `gridColumnSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `gridRow` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `gridRowSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `horizontalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `margin` | property | `Insets` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `panTouchCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pinch on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pinch on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: tap on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: tap on Grid: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on Grid: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `clipsContent` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ◐ cannot read clipsContent of Grid - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ◐ cannot read clipsContent of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ◐ cannot read clipsContent of Grid - Android's driver has no path for it yet |
| `letsInputThrough` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: ◐ cannot read letsInputThrough of Grid - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ◐ cannot read letsInputThrough of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ⌛ | ⌛ | ⌛ | ◐ |  |  | a run of other sources said: ◐ cannot read padding of Grid - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ◐ cannot read padding of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ◐ cannot read padding of Grid - Android's driver has no path for it yet; WinUI 3: cannot read padding of Grid - WinUI's panel places its children where StateUI's layout says; their frames prove it |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read shape of Grid - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read shape of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read shape of Grid - Android's driver has no path for it yet |
| `stroke` | property | `Brush` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read stroke of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read stroke of Grid - Android's driver has no path for it yet |
| `strokeWidth` | property | `Double` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read strokeWidth of Grid - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read strokeWidth of Grid - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read strokeWidth of Grid - Android's driver has no path for it yet |
