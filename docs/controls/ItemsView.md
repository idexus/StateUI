<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ItemsView

The platform's own collection of items: StateUI says which items there are, in order, and builds the one the platform asks for; the platform scrolls them, holds each in a cell it reuses, lets the user choose and open one, and tells assistive technology about them.

```swift
@State var chosen: String? = nil

ItemsView(["Apple", "Banana", "Cherry"]) { fruit in
    Label(fruit).padding(14, 10)
}
.selection($chosen)
.onItemActivated { fruit in chosen = fruit }
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

| Host | Created | Members (76) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 33 ✅ · 1 ☑️ | `NSCollectionView` / `NSTableView` |  |
| UIKit | ✅ | 29 ✅ · 3 – | `UICollectionView` |  |
| Android Views | ✅ | 60 ✅ · 1 ☑️ | AndroidX `RecyclerView` |  |
| WinUI 3 | ✅ | 60 ✅ | `ItemsView` |  |
| GTK 4 | ✅ | 42 ✅ | `GtkListView` / `GtkGridView` |  |
| Web |  |  | semantic list or grid | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Collections/ItemsViewContract.swift`.

## ItemsView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `items` | property | `ItemsEntries` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `itemsLayout` | property | `ItemsLayout` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `selectionMode` | property | `SelectionMode` | native | 🔌 | 🔌 | 🔌 | ✅ | ✅ |  | only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch; Android Views: only through the host's own: read selectionMode of ItemsView: the mode the relay keeps, which its cells tell TalkBack |
| `selectedItems` | property | `[String]` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch |
| `selectionChanged` | event | `[String]` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: choose on ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: choose on ItemsView: the collection's delegate told, no touch |
| `itemActivated` | event | `String` | adaptive | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: activate on an item of ItemsView: the collection's delegate told, no click; UIKit: only through the host's own: activate on an item of ItemsView: the collection's delegate told, no touch; GTK 4: cannot activate on Label - GTK's driver has no path for it yet |
| `endReachedWithin` | property | `Int` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `endReached` | event |  | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `realizedChanged` | event | `[String]` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `scrollTo` | act | `(String, ScrollAnchor) -> Void` |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | · |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; GTK 4: cannot read accessibilityHeadingLevel of ItemsView - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityHint of ItemsView - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityLabel of ItemsView - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read automationExcludedWithChildren of ItemsView - GTK's driver has no path for it yet |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | ✅ | – | ✅ | ✅ | ⏸ |  | UIKit: ItemsView takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on ItemsView.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read isAccessibilityHidden of ItemsView - GTK's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | ✅ | – | ✅ | ✅ |  |  | UIKit: ItemsView takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotX of ItemsView - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotY of ItemsView - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read rotation of ItemsView - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of ItemsView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationX of ItemsView - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of ItemsView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationY of ItemsView - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scale of ItemsView - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleX of ItemsView - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleY of ItemsView - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationX of ItemsView - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of ItemsView: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationY of ItemsView - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  | ✅ | – | ✅ | ✅ | ⏸ |  | UIKit: ItemsView takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on ItemsView.isFocusedChanged, not realized yet |
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
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: pinch on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on ItemsView: the view's listening handed the recognizer's states, no touch sent; GTK 4: only through the host's own: pinch on ItemsView: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on ItemsView: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on ItemsView: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
