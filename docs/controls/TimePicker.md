<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TimePicker

A time of day, chosen from the platform's own clock.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md)

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

| Host | Created | Members (78) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 33 ✅ · 1 ☑️ | `NSDatePicker` in time mode |  |
| UIKit | ✅ | 30 ✅ | `UIDatePicker` in time mode |  |
| Android Views | ✅ | 53 ✅ · 1 ☑️ · 3 – | `TimePickerDialog` |  |
| WinUI 3 | ✅ | 58 ✅ | `TimePicker` |  |
| GTK 4 |  |  | no honest native counterpart | not realized |
| Web |  |  | `<input type=time>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/TimePickerContract.swift`.

## TimePicker's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | event |  | native |  |  | · |  |  |  | not realized; UIKit: not realized; Android Views: cannot open on TimePicker - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `format` | property | `String` | native |  |  | · | · |  |  | not realized; UIKit: not realized; Android Views: cannot read format of TimePicker - Android's driver has no path for it yet; WinUI 3: cannot read format of TimePicker - WinUI's time picker holds no format: it writes hours and minutes in the user's own clock; GTK 4: not realized |
| `isOpen` | property | `Bool` | native |  |  | · |  |  |  | not realized; UIKit: not realized; Android Views: cannot open on TimePicker - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `onOpened` (`opened`) | event |  | native |  |  | · |  |  |  | not realized; UIKit: not realized; Android Views: cannot open on TimePicker - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `time` | property | `ClockTime` | native | 🔌 | ✅ | · | ✅ |  |  | only through the host's own: pickTime on TimePicker: the host's change handler called, not the picker's action; Android Views: cannot read time of TimePicker - Android's driver has no path for it yet; GTK 4: not realized |
| `onTimeChanged` (`timeChanged`) | event | `ClockTime` | native | 🔌 | ✅ | · | ✅ |  |  | only through the host's own: pickTime on TimePicker: the host's change handler called, not the picker's action; Android Views: cannot read time of TimePicker - Android's driver has no path for it yet; GTK 4: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ |  |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; GTK 4: not realized |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | ✅ | ✅ | – | ✅ |  |  | Android Views: TimePicker takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ✅ | – | ✅ |  |  | Android Views: TimePicker takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read pivotX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read pivotY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read rotation of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  |  |  | only through the host's own: read rotationX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of TimePicker: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  |  |  | only through the host's own: read rotationY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of TimePicker: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read scale of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read scaleX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read scaleY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read translationX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: read translationY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: not realized |
| `unfocus` | act | `() -> Void` |  | ✅ | ✅ | – | ✅ |  |  | Android Views: TimePicker takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `width` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off.; GTK 4: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pinch on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: tap on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ |  |  | only through the host's own: tap on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: not realized |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `textColor` | property | `Color` | native | ✅ |  | ✅ | ✅ |  |  | UIKit: not realized; GTK 4: not realized |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ |  | ✅ | ✅ |  |  | UIKit: not realized; GTK 4: not realized |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native | ✅ |  | · | ✅ |  |  | UIKit: not realized; Android Views: cannot read a family - Android's typeface keeps no family's name; GTK 4: not realized |
| `fontSize` | property | `Double` | native | ✅ |  | ✅ | ✅ |  |  | UIKit: not realized; GTK 4: not realized |
