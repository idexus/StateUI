<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ZStack

Lays its children one over another, each in the whole room or in the area it names.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (73) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 26 ✅ | custom `NSView` |  |
| UIKit | ✅ | 25 ✅ | custom `UIView` |  |
| Android Views | ⌛ |  | custom `ViewGroup` | a run of other sources said: ◐ cannot read what reaches ColorBox - Android's driver has no path for it yet |
| WinUI 3 | ⌛ |  | `Canvas` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkFixed` | no run of it on these sources |
| Web |  |  | `position: absolute` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/ZStackContract.swift`.

## ZStack's own members

ZStack declares no members of its own.

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | ⌛ | ⌛ |  |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: a run of other sources said: · cannot read a heading's level - Android marks a heading, not its level; WinUI 3: a run of other sources said: ✅ |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `background` | property | `Background` | native | ✅ | · | ⌛ | ⌛ |  |  | UIKit: cannot read background of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `focus` | act | `() -> Bool` |  | · | · | ⌛ | ⌛ |  |  | cannot focus ZStack: it takes no keyboard focus here; UIKit: cannot focus ZStack: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus ZStack: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: · cannot read what reaches ZStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `isFocusedChanged` | event | `Bool` | native | · | · | ⌛ | ⌛ |  |  | cannot focus ZStack: it takes no keyboard focus here; UIKit: cannot focus ZStack: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus ZStack: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read pivotX of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read pivotY of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read rotation of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read rotationX of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read rotationY of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `scale` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read scale of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read scaleX of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read scaleY of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `style` | property | `Name` | structure | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `translationX` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read translationX of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: read translationY of ZStack: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of ZStack: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | · | · | ⌛ | ⌛ |  |  | cannot focus ZStack: it takes no keyboard focus here; UIKit: cannot focus ZStack: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus ZStack: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `width` | property | `Double` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `zIndex` | property | `Int` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `canDrag` | property | `Bool` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `dragStarting` | event |  | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `dragText` | property | `String` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `margin` | property | `Insets` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `panTouchCount` | property | `Int` | structure | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pinch on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: hover on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: hover on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: hover on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: hover on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: hover on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: pan on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: tap on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | 🪞 | 🪞 | ⌛ | ⌛ |  |  | only through the host's own: tap on ZStack: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ZStack: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |  |  | ⌛ | ⌛ |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `clipsContent` | property | `Bool` | native | ◐ | ◐ | ⌛ | ⌛ |  |  | cannot read clipsContent of ZStack - AppKit's driver has no path for it yet; UIKit: cannot read clipsContent of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ◐ cannot read clipsContent of ZStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `letsInputThrough` | property | `Bool` | native | ◐ | ◐ | ⌛ | ⌛ |  |  | cannot read letsInputThrough of ZStack - AppKit's driver has no path for it yet; UIKit: cannot read letsInputThrough of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ◐ | ◐ | ⌛ | ⌛ |  |  | cannot read padding of ZStack - AppKit's driver has no path for it yet; UIKit: cannot read padding of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ◐ cannot read padding of ZStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI | · | · | ⌛ | ⌛ |  |  | cannot read shape of ZStack - AppKit's driver has no path for it yet; UIKit: cannot read shape of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read shape of ZStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `stroke` | property | `Brush` | stateUI |  | · | ⌛ | ⌛ |  |  | not realized; UIKit: cannot read stroke of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read stroke of ZStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeWidth` | property | `Double` | stateUI | · | · | ⌛ | ⌛ |  |  | cannot read strokeWidth of ZStack - AppKit's driver has no path for it yet; UIKit: cannot read strokeWidth of ZStack - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read strokeWidth of ZStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
