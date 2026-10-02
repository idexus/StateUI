<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TimePicker

A time of day, chosen from the platform's own clock.

```swift
@State var alarm = ClockTime(hour: 7, minute: 0)

TimePicker($alarm)
    .format("t")
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (78) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 35 ✅ · 1 ☑️ · 26 ✓ · 1 – | `NSDatePicker` in time mode |  |
| UIKit | ✅ | 31 ✅ · 25 ✓ | `UIDatePicker` in time mode |  |
| Android Views | ✅ | 58 ✅ · 1 ☑️ · 1 ✓ · 3 – | `TimePickerDialog` |  |
| WinUI 3 | ✅ | 58 ✅ | `TimePicker` |  |
| GTK 4 | ⌛ | 45 ✅ · 11 ✓ · 1 – | an hour's and a minute's `GtkSpinButton` in a `GtkPopover` |  |
| Web |  |  | `<input type=time>` | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/TimePickerContract.swift`.

## TimePicker's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | event |  | native |  |  | ✅ |  | ⌛ |  | not realized; UIKit: not realized; WinUI 3: not realized |
| `format` | property | `String` | native |  |  | ✓ | · | ⌛ |  | not realized; UIKit: not realized; Android Views: only through the host's own: read format of TimePicker: the pattern the relay writes the field in; WinUI 3: cannot read format of TimePicker - WinUI's time picker holds no format: it writes hours and minutes in the user's own clock |
| `isOpen` | property | `Bool` | native |  |  | ✅ |  | ⌛ |  | not realized; UIKit: not realized; WinUI 3: not realized |
| `onOpened` (`opened`) | event |  | native |  |  | ✅ |  | ⌛ |  | not realized; UIKit: not realized; WinUI 3: not realized |
| `time` | property | `ClockTime` | native | ✅ | ✅ | ✅ | ✅ | ⌛ |  |  |
| `onTimeChanged` (`timeChanged`) | event | `ClockTime` | native | ✓ | ✅ | ✅ | ✅ | ⌛ |  | only through the host's own: pickTime on TimePicker: the host's change handler called, not the picker's action |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | – |  | GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code. |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | ✅ |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | ✅ | ✅ | – | ✅ | ✅ |  | Android Views: TimePicker takes no keyboard focus here: it refuses it, and nothing is heard |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ | ✅ |  |  |  |  | Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ | ✅ | – | ✅ | ✅ |  | Android Views: TimePicker takes no keyboard focus here: it refuses it, and nothing is heard |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read pivotX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotX of TimePicker: the host's own transform: GTK reads back no part of one |
| `pivotY` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read pivotY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotY of TimePicker: the host's own transform: GTK reads back no part of one |
| `rotation` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read rotation of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotation of TimePicker: the host's own transform: GTK reads back no part of one |
| `rotationX` | property | `Double` | native | ✓ | ✓ | ✅ |  | ✓ |  | only through the host's own: read rotationX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of TimePicker: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationX of TimePicker: the host's own transform: GTK reads back no part of one |
| `rotationY` | property | `Double` | native | ✓ | ✓ | ✅ |  | ✓ |  | only through the host's own: read rotationY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of TimePicker: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: only through the host's own: read rotationY of TimePicker: the host's own transform: GTK reads back no part of one |
| `scale` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read scale of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scale of TimePicker: the host's own transform: GTK reads back no part of one |
| `scaleX` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read scaleX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleX of TimePicker: the host's own transform: GTK reads back no part of one |
| `scaleY` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read scaleY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleY of TimePicker: the host's own transform: GTK reads back no part of one |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read translationX of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationX of TimePicker: the host's own transform: GTK reads back no part of one |
| `translationY` | property | `Double` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: read translationY of TimePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of TimePicker: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationY of TimePicker: the host's own transform: GTK reads back no part of one |
| `unfocus` | act | `() -> Void` |  | ✅ | ✅ | – | ✅ | ✅ |  | Android Views: TimePicker takes no keyboard focus here: it refuses it, and nothing is heard |
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
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ✅ | ⌛ |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure | ✓ | ✓ | ☑️ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✓ | ✓ | ✅ | ✅ | ✓ |  | only through the host's own: pinch on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on TimePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: only through the host's own: pinch on TimePicker: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: hover on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: pan on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: tap on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: tap on TimePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on TimePicker: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `textColor` | property | `Color` | native | ✅ |  | ✅ | ✅ | ✅ |  | UIKit: not realized |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ |  | ✅ | ✅ | ✅ |  | UIKit: not realized |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive | – |  |  |  |  |  | macOS gives an application no text size of the user's to follow.; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native | ✅ |  | · | ✅ | ✅ |  | UIKit: not realized; Android Views: cannot read a family - Android's typeface keeps no family's name |
| `fontSize` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  | UIKit: not realized |
