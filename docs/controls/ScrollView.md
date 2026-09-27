<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ScrollView

A scrollable container.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (77) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 25 ✅ · 1 ☑️ | `NSScrollView` |  |
| UIKit | ✅ | 28 ✅ | `UIScrollView` |  |
| Android Views | ✅ | 49 ✅ | `ScrollView` / `HorizontalScrollView` |  |
| WinUI 3 | ⌛ |  | `ScrollViewer` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkScrolledWindow` | no run of it on these sources |
| Web |  |  | `overflow: auto` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/ScrollViewContract.swift`.

## ScrollView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalScrollBarVisibility` | property | `ScrollBarVisibility` | adaptive | · | · | · | ⌛ |  |  | cannot read horizontalScrollBarVisibility of ScrollView - AppKit's driver has no path for it yet; UIKit: cannot read horizontalScrollBarVisibility of ScrollView - UIKit's driver has no path for it yet; Android Views: cannot read horizontalScrollBarVisibility of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `orientation` | property | `ScrollOrientation` | native | ✅ | ✅ | ◐ | ⌛ |  |  | Android Views: cannot scroll on ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `scrollOffset` | property | `Point` | structure | ◐ | ✅ | · | ⌛ |  |  | cannot read scrollOffset of ScrollView - AppKit's driver has no path for it yet; Android Views: cannot read scrollOffset of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `onScrollStopped` (`scrollStopped`) | event |  | native | 🪞 | ✅ | · | ⌛ |  |  | only through the host's own: scroll on ScrollView: the host's movement moved, not the clip view; Android Views: cannot scroll on ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `scrollXChanged` | event | `Double` | native | 🪞 | ✅ | · | ⌛ |  |  | only through the host's own: scroll on ScrollView: the host's movement moved, not the clip view; Android Views: cannot scroll on ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `scrollYChanged` | event | `Double` | native | ◐ | ✅ | · | ⌛ |  |  | cannot read scrollOffset of ScrollView - AppKit's driver has no path for it yet; Android Views: cannot read scrollOffset of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `verticalScrollBarVisibility` | property | `ScrollBarVisibility` | adaptive | · | · | · | ⌛ |  |  | cannot read verticalScrollBarVisibility of ScrollView - AppKit's driver has no path for it yet; UIKit: cannot read verticalScrollBarVisibility of ScrollView - UIKit's driver has no path for it yet; Android Views: cannot read verticalScrollBarVisibility of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

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
| `background` | property | `Background` | native | ☑️ | · | ✅ | ⌛ |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: cannot read background of ScrollView - UIKit's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `focus` | act | `() -> Bool` |  | · | · | · | ⌛ |  |  | cannot focus ScrollView: it takes no keyboard focus here; UIKit: cannot focus ScrollView: it takes no keyboard focus here; Android Views: cannot focus ScrollView: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native |  | · |  | ⌛ |  |  | not realized; UIKit: cannot read isEnabled of ScrollView - UIKit's driver has no path for it yet; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isFocusedChanged` | event | `Bool` | native | · | · | · | ⌛ |  |  | cannot focus ScrollView: it takes no keyboard focus here; UIKit: cannot focus ScrollView: it takes no keyboard focus here; Android Views: cannot focus ScrollView: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read pivotX of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read pivotY of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotation of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotationX of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotationY of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: not realized |
| `scale` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scale of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scaleX of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scaleY of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `style` | property | `Name` | structure |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `translationX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read translationX of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read translationY of ScrollView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of ScrollView: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | · | · | · | ⌛ |  |  | cannot focus ScrollView: it takes no keyboard focus here; UIKit: cannot focus ScrollView: it takes no keyboard focus here; Android Views: cannot focus ScrollView: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
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
| `panTouchCount` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pinch on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: tap on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: tap on ScrollView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ScrollView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read padding of ScrollView - AppKit's driver has no path for it yet; UIKit: cannot read padding of ScrollView - UIKit's driver has no path for it yet; Android Views: cannot read padding of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI | · | · | · | ⌛ |  |  | cannot read shape of ScrollView - AppKit's driver has no path for it yet; UIKit: cannot read shape of ScrollView - UIKit's driver has no path for it yet; Android Views: cannot read shape of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `stroke` | property | `Brush` | stateUI | · | · | · | ⌛ |  |  | cannot read stroke of ScrollView - AppKit's driver has no path for it yet; UIKit: cannot read stroke of ScrollView - UIKit's driver has no path for it yet; Android Views: cannot read stroke of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `strokeWidth` | property | `Double` | stateUI | · | · | · | ⌛ |  |  | cannot read strokeWidth of ScrollView - AppKit's driver has no path for it yet; UIKit: cannot read strokeWidth of ScrollView - UIKit's driver has no path for it yet; Android Views: cannot read strokeWidth of ScrollView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
