<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ItemsView

The platform's own collection of items: StateUI says which items there are, in order, and builds the one the platform asks for; the platform scrolls them, holds each in a cell it reuses, lets the user choose and open one, and tells assistive technology about them.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (76) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSCollectionView` / `NSTableView` | a run of other sources said: ✅ |
| UIKit | ⌛ |  | `UICollectionView` | a run of other sources said: ✅ |
| Android Views | ✅ | 61 ✅ | AndroidX `RecyclerView` |  |
| WinUI 3 |  |  | `ItemsView` | no run of it on these sources |
| GTK 4 |  |  | `GtkListView` / `GtkGridView` | no run of it on these sources |
| Web |  |  | semantic list or grid | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Collections/ItemsViewContract.swift`.

## ItemsView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `items` | property | `ItemsEntries` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `itemsLayout` | property | `ItemsLayout` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `selectionMode` | property | `SelectionMode` | native | ⌛ | ⌛ | 🪞 |  |  |  | a run of other sources said: 🪞 only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: a run of other sources said: 🪞 only through the host's own: choose on ItemsView: the collection's delegate told, no touch; Android Views: only through the host's own: read selectionMode of ItemsView: the mode the relay keeps, which its cells tell TalkBack |
| `selectedItems` | property | `[String]` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: a run of other sources said: 🪞 only through the host's own: choose on ItemsView: the collection's delegate told, no touch |
| `selectionChanged` | event | `[String]` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: a run of other sources said: 🪞 only through the host's own: choose on ItemsView: the collection's delegate told, no touch |
| `itemActivated` | event | `String` | adaptive | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: activate on an item of ItemsView: the collection's delegate told, no click; UIKit: a run of other sources said: 🪞 only through the host's own: activate on an item of ItemsView: the collection's delegate told, no touch |
| `endReachedWithin` | property | `Int` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `endReached` | event |  | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `realizedChanged` | event | `[String]` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `scrollTo` | act | `(String, ScrollAnchor) -> Void` |  | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ⌛ | ⌛ | · |  |  |  | a run of other sources said: · cannot read a heading's level - AppKit marks a heading, not its level; UIKit: a run of other sources said: · cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `accessibilityLabel` | property | `String` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `automationExcludedWithChildren` | property | `Bool` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `background` | property | `Background` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ☑️ AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: a run of other sources said: not realized |
| `focus` | act | `() -> Bool` |  | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: · cannot focus ItemsView: it takes no keyboard focus here; UIKit: a run of other sources said: · cannot focus ItemsView: it takes no keyboard focus here |
| `frame` | property | `Rect` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `isFocusedChanged` | event | `Bool` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: · cannot focus ItemsView: it takes no keyboard focus here; UIKit: a run of other sources said: · cannot focus ItemsView: it takes no keyboard focus here |
| `isVisible` | property | `Bool` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself |
| `pivotY` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself |
| `rotation` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself |
| `rotationX` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself |
| `rotationY` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself |
| `scale` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself |
| `scaleX` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself |
| `scaleY` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself |
| `style` | property | `Name` | structure | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `translationX` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself |
| `translationY` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself |
| `unfocus` | act | `() -> Void` |  | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: · cannot focus ItemsView: it takes no keyboard focus here; UIKit: a run of other sources said: · cannot focus ItemsView: it takes no keyboard focus here |
| `width` | property | `Double` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `zIndex` | property | `Int` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `area` | property | `Area` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `canDrag` | property | `Bool` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `onDragOver` (`dragOver`) | event |  | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `dragStarting` | event |  | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `dragText` | property | `String` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `onDrop` (`drop`) | event | `String` | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native | ⌛ | ⌛ |  |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `gridColumn` | property | `Int` | stateUI | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `gridColumnSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `gridRow` | property | `Int` | stateUI | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `gridRowSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `horizontalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `margin` | property | `Insets` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
| `panTouchCount` | property | `Int` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pinch on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pinch on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: 🪞 only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ✅ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅ |
