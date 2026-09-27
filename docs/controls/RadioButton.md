<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# RadioButton

One choice out of several, where picking one clears the rest.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (81) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 38 ✅ · 1 ☑️ | `NSButton` radio |  |
| UIKit | ⌛ |  | composed by StateUI | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `RadioButton` | a run of other sources said: ✅ |
| WinUI 3 | ⌛ |  | `RadioButton` | a run of other sources said: ✅ |
| GTK 4 |  |  | grouped `GtkCheckButton` | no run of it on these sources |
| Web |  |  | `<input type=radio>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/RadioButtonContract.swift`.

## RadioButton's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `groupName` | property | `Name` | stateUI | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `isOn` | property | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: 🪞 only through the host's own: read isOn of RadioButton: the host's own flag, not the button's state; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onToggled` (`toggled`) | event | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | ⌛ | ⌛ | ⌛ |  |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: a run of other sources said: · cannot read a heading's level - UIKit marks a heading, not its level; Android Views: a run of other sources said: · cannot read a heading's level - Android marks a heading, not its level; WinUI 3: a run of other sources said: ✅ |
| `accessibilityHint` | property | `String` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `accessibilityLabel` | property | `String` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `background` | property | `Background` | native | ☑️ | ⌛ | ⌛ | ⌛ |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `focus` | act | `() -> Bool` |  | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: · cannot focus RadioButton: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus RadioButton: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `frame` | property | `Rect` | structure | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: · cannot focus RadioButton: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus RadioButton: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `isVisible` | property | `Bool` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read pivotX of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotX of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read pivotY of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotY of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read rotation of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotation of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read rotationX of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationX of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read rotationY of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationY of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `scale` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read scale of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scale of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read scaleX of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleX of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read scaleY of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleY of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `style` | property | `Name` | structure | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `translationX` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read translationX of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationX of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read translationY of RadioButton: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationY of RadioButton: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: · cannot focus RadioButton: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus RadioButton: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `width` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `zIndex` | property | `Int` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `area` | property | `Area` | structure | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `canDrag` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `dragStarting` | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `dragText` | property | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDrop` (`drop`) | event | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridColumn` | property | `Int` | stateUI | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridRow` | property | `Int` | stateUI | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `margin` | property | `Insets` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `panTouchCount` | property | `Int` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pinch on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pinch on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: hover on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: pan on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: tap on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: tap on RadioButton: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on RadioButton: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `textCase` | property | `TextCase` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `textColor` | property | `Color` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `fontFamily` | property | `Name` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read a family - Android's typeface keeps no family's name; WinUI 3: a run of other sources said: ✅ |
| `fontSize` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | · | ⌛ | ⌛ | ⌛ |  |  | cannot read padding of RadioButton - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read padding of RadioButton - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `stroke` | property | `Brush` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `strokeWidth` | property | `Double` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
