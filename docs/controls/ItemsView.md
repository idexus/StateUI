<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ItemsView

The platform's own collection of items: StateUI says which items there are, in order, and builds the one the platform asks for; the platform scrolls them, holds each in a cell it reuses, lets the user choose and open one, and tells assistive technology about them.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (76) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 30 ✅ · 1 ☑️ | `NSCollectionView` / `NSTableView` |  |
| UIKit | ✅ | 29 ✅ | `UICollectionView` |  |
| Android Views | ⌛ |  | AndroidX `RecyclerView` | a run of other sources said: not realized |
| WinUI 3 |  |  | `ItemsView` | no run of it on these sources |
| GTK 4 |  |  | `GtkListView` / `GtkGridView` | no run of it on these sources |
| Web |  |  | semantic list or grid | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Collections/ItemsViewContract.swift`.

## ItemsView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `items` | property | `ItemsEntries` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `itemsLayout` | property | `ItemsLayout` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `selectionMode` | property | `SelectionMode` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch; Android Views: a run of other sources said: not realized |
| `selectedItems` | property | `[String]` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch; Android Views: a run of other sources said: not realized |
| `selectionChanged` | event | `[String]` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch; Android Views: a run of other sources said: not realized |
| `itemActivated` | event | `String` | adaptive | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: activate on an item of ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: activate on an item of ItemsView: the collection's delegate told, no touch; Android Views: a run of other sources said: not realized |
| `endReachedWithin` | property | `Int` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `endReached` | event |  | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `realizedChanged` | event | `[String]` | structure | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `scrollTo` | act | `(String, ScrollAnchor) -> Void` |  | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | ⌛ |  |  |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: a run of other sources said: not realized |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `background` | property | `Background` | native | ☑️ |  | ⌛ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `focus` | act | `() -> Bool` |  | · | · | ⌛ |  |  |  | cannot focus ItemsView: it takes no keyboard focus here; UIKit: cannot focus ItemsView: it takes no keyboard focus here; Android Views: a run of other sources said: not realized |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `height` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `ignoresInput` | property | `Bool` | native | ✅ |  | ⌛ |  |  |  | UIKit: not realized; Android Views: a run of other sources said: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `isEnabled` | property | `Bool` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `isFocusedChanged` | event | `Bool` | native | · | · | ⌛ |  |  |  | cannot focus ItemsView: it takes no keyboard focus here; UIKit: cannot focus ItemsView: it takes no keyboard focus here; Android Views: a run of other sources said: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `opacity` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `pivotX` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `pivotY` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `rotation` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `rotationX` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `scale` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `scaleX` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `scaleY` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `style` | property | `Name` | structure |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `translationX` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `translationY` | property | `Double` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: not realized |
| `unfocus` | act | `() -> Void` |  | · | · | ⌛ |  |  |  | cannot focus ItemsView: it takes no keyboard focus here; UIKit: cannot focus ItemsView: it takes no keyboard focus here; Android Views: a run of other sources said: not realized |
| `width` | property | `Double` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `zIndex` | property | `Int` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `canDrag` | property | `Bool` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `dragStarting` | event |  | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `dragText` | property | `String` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  | ⌛ |  |  |  | not realized; UIKit: not realized; Android Views: a run of other sources said: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `margin` | property | `Insets` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
| `panTouchCount` | property | `Int` | structure | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `panXChannel` | property | `Int` | structure | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `panYChannel` | property | `Int` | structure | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pinch on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `swipeThreshold` | property | `Double` | structure | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `tapCount` | property | `Int` | structure | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `onTapped` (`tapped`) | event |  | native | 🪞 | 🪞 | ⌛ |  |  |  | only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: not realized |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ⌛ |  |  |  | Android Views: a run of other sources said: not realized |
