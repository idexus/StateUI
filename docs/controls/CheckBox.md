<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# CheckBox

A box that is ticked or not.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TintElement](tiers/TintElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (69) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSButton` checkbox | a run of other sources said: ✅ |
| UIKit | ⌛ |  | composed by StateUI | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `CheckBox` | a run of other sources said: ✅ |
| WinUI 3 | ✅ | 56 ✅ | `CheckBox` |  |
| GTK 4 |  |  | `GtkCheckButton` | no run of it on these sources |
| Web |  |  | `<input type=checkbox>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/CheckBoxContract.swift`.

## CheckBox's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isOn` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: 🪞 only through the host's own: read isOn of CheckBox: the host's own flag, not the button's state; Android Views: a run of other sources said: ✅ |
| `onToggled` (`toggled`) | event | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

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
| `background` | property | `Background` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ☑️ AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: ✅ |
| `focus` | act | `() -> Bool` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: · cannot focus CheckBox: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus CheckBox: it takes no keyboard focus here |
| `frame` | property | `Rect` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `isFocusedChanged` | event | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: · cannot focus CheckBox: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus CheckBox: it takes no keyboard focus here |
| `isVisible` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read pivotX of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotX of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read pivotY of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotY of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read rotation of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotation of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationX of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationX of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `rotationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: 🪞 only through the host's own: read rotationY of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationY of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: not realized |
| `scale` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scale of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scale of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scaleX of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleX of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read scaleY of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleY of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `style` | property | `Name` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `translationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read translationX of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationX of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read translationY of CheckBox: the host's own transform, checked against the layer it composed itself; UIKit: a run of other sources said: 🪞 only through the host's own: read translationY of CheckBox: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: · cannot focus CheckBox: it takes no keyboard focus here; Android Views: a run of other sources said: · cannot focus CheckBox: it takes no keyboard focus here |
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
| `panTouchCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pinch on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pinch on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: hover on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: hover on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: pan on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: pan on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: tap on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: tap on CheckBox: handed to the host's recognizer or handler, no NSEvent sent; UIKit: a run of other sources said: 🪞 only through the host's own: tap on CheckBox: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |

## From [TintElement](tiers/TintElement.md)

A control's one accent colour.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `tint` | property | `Color` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: · cannot read tint of CheckBox - Android's driver has no path for it yet |
