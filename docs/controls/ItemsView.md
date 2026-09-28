<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ItemsView

The platform's own collection of items: StateUI says which items there are, in order, and builds the one the platform asks for; the platform scrolls them, holds each in a cell it reuses, lets the user choose and open one, and tells assistive technology about them.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (76) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSCollectionView` / `NSTableView` | no run of it on these sources |
| UIKit |  |  | `UICollectionView` | no run of it on these sources |
| Android Views |  |  | AndroidX `RecyclerView` | no run of it on these sources |
| WinUI 3 | ✅ | 60 ✅ | `ItemsView` |  |
| GTK 4 | ✅ | 23 ✅ | `GtkListView` / `GtkGridView` |  |
| Web |  |  | semantic list or grid | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Collections/ItemsViewContract.swift`.

## ItemsView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `items` | property | `ItemsEntries` | native |  |  |  | ✅ | ✅ |  |  |
| `itemsLayout` | property | `ItemsLayout` | native |  |  |  | ✅ | · |  | GTK 4: cannot read where Label stands - GTK's driver has no path for it yet |
| `selectionMode` | property | `SelectionMode` | native |  |  |  | ✅ | · |  | GTK 4: cannot read selectionMode of ItemsView - GTK's driver has no path for it yet |
| `selectedItems` | property | `[String]` | native |  |  |  | ✅ | · |  | GTK 4: cannot read selectionMode of ItemsView - GTK's driver has no path for it yet |
| `selectionChanged` | event | `[String]` | native |  |  |  | ✅ | · |  | GTK 4: cannot read selectionMode of ItemsView - GTK's driver has no path for it yet |
| `itemActivated` | event | `String` | adaptive |  |  |  | ✅ | · |  | GTK 4: cannot activate on Label - GTK's driver has no path for it yet |
| `endReachedWithin` | property | `Int` | native |  |  |  | ✅ | ✅ |  |  |
| `endReached` | event |  | native |  |  |  | ✅ | ✅ |  |  |
| `realizedChanged` | event | `[String]` | structure |  |  |  | ✅ | ✅ |  |  |
| `scrollTo` | act | `(String, ScrollAnchor) -> Void` |  |  |  |  | ✅ | · |  | GTK 4: cannot read where ItemsView stands - GTK's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityHeadingLevel of ItemsView - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityHint of ItemsView - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityLabel of ItemsView - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ⏸ |  | GTK 4: waits on ItemsView.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure |  |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read pivotX of ItemsView - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read pivotY of ItemsView - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read rotation of ItemsView - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read rotationX of ItemsView - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read rotationY of ItemsView - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scale of ItemsView - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scaleX of ItemsView - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scaleY of ItemsView - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `translationX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read translationX of ItemsView - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read translationY of ItemsView - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ⏸ |  | GTK 4: waits on ItemsView.isFocusedChanged, not realized yet |
| `width` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure |  |  |  | ✅ | ✅ |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  |  | ✅ | ✅ |  |  |
| `gridColumn` | property | `Int` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native |  |  |  | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native |  |  |  | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  | ✅ | · |  | GTK 4: cannot pinch on ItemsView - GTK's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on ItemsView - GTK's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on ItemsView - GTK's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on ItemsView - GTK's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on ItemsView - GTK's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on ItemsView - GTK's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  | ✅ | · |  | GTK 4: cannot pan on ItemsView - GTK's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot tap on ItemsView - GTK's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot tap on ItemsView - GTK's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ | ✅ |  |  |
