<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SearchField

A text field for what to search for, shown as the platform's search field.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [InputView](tiers/InputView.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [TintElement](tiers/TintElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (89) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSSearchField` | a run of other sources said: ✅ |
| UIKit | ⌛ |  | `UISearchBar` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `SearchView` | a run of other sources said: ✅ |
| WinUI 3 | ✅ | 58 ✅ | `AutoSuggestBox` |  |
| GTK 4 |  |  | `GtkSearchEntry` | no run of it on these sources |
| Web |  |  | `<input type=search>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/SearchFieldContract.swift`.

## SearchField's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `returnKey` | property | `ReturnKey` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: · cannot read returnKey of SearchField - Android's driver has no path for it yet; WinUI 3: not realized |
| `onSubmitted` (`submitted`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

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
| `background` | property | `Background` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: ☑️ AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `focus` | act | `() -> Bool` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `frame` | property | `Rect` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ◐ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ◐ waits on SearchField.isReadOnly; WinUI 3: waits on SearchField.isReadOnly |
| `isFocusedChanged` | event | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `isVisible` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read pivotX of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotX of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read pivotY of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotY of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read rotation of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotation of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationX of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationX of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `rotationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationY of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationY of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `scale` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scale of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scale of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scaleX of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleX of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scaleY of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleY of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `style` | property | `Name` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `translationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read translationX of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationX of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read translationY of SearchField: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationY of SearchField: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
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
| `panTouchCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pinch on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pinch on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: tap on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: tap on SearchField: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on SearchField: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [InputView](tiers/InputView.md)

What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `cursorPosition` | property | `Int` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read cursorPosition of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read cursorPosition of SearchField - Android's driver has no path for it yet; WinUI 3: not realized |
| `inputPurpose` | property | `InputPurpose` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read inputPurpose of SearchField - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isReadOnly` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isSpellCheckEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read isSpellCheckEnabled of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isTextPredictionEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read isTextPredictionEnabled of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `maximumLength` | property | `Int` | native | ⌛ | ⌛ | ⌛ | ◐ |  |  | a run of other sources said: ◐ cannot read maximumLength of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ◐ cannot read maximumLength of SearchField - Android's driver has no path for it yet; WinUI 3: cannot read maximumLength of SearchField - WinUI's search box holds no bound: the host cuts what is typed; typing proves it |
| `placeholder` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read placeholder of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read placeholder of SearchField - Android's driver has no path for it yet |
| `placeholderColor` | property | `Color` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read placeholderColor of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read placeholderColor of SearchField - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read placeholderColor of SearchField - Android's driver has no path for it yet; WinUI 3: not realized |
| `selectionLength` | property | `Int` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read selectionLength of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read selectionLength of SearchField - Android's driver has no path for it yet; WinUI 3: not realized |
| `onTextChanged` (`textChanged`) | event | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ⌛ | ⌛ | ⌛ | ◐ |  |  | a run of other sources said: ◐ waits on SearchField.textCase; UIKit: a run of other sources said: ◐ waits on SearchField.textCase; Android Views: a run of other sources said: ◐ waits on SearchField.isReadOnly; WinUI 3: waits on SearchField.isReadOnly |
| `textCase` | property | `TextCase` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `textColor` | property | `Color` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `fontFamily` | property | `Name` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read a family - Android's typeface keeps no family's name |
| `fontSize` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read horizontalTextAlignment of SearchField - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read horizontalTextAlignment of SearchField - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `verticalTextAlignment` | property | `TextAlignment` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [TintElement](tiers/TintElement.md)

A control's one accent colour.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `tint` | property | `Color` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
