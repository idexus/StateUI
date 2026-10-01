<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# DatePicker

A day, chosen from the platform's own calendar.

```swift
@State var birthday = CalendarDate(year: 1990, month: 6, day: 1)

DatePicker($birthday)
    .minimumDate(CalendarDate(year: 1900, month: 1, day: 1))
    .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
```

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

| Host | Created | Members (80) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 35 ✅ · 1 ☑️ | `NSDatePicker` |  |
| UIKit | ✅ | 29 ✅ · 3 – | `UIDatePicker` |  |
| Android Views | ✅ | 53 ✅ · 1 ☑️ · 3 – | `DatePickerDialog` |  |
| WinUI 3 | ✅ | 63 ✅ · 1 ☑️ | `CalendarDatePicker` |  |
| GTK 4 | ✅ | 39 ✅ · 1 ☑️ | `GtkCalendar` in a `GtkPopover` |  |
| Web |  |  | `<input type=date>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/DatePickerContract.swift`.

## DatePicker's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | event |  | native |  |  | · | ✅ | ✅ |  | not realized; UIKit: not realized; Android Views: cannot open on DatePicker - Android's driver has no path for it yet |
| `date` | property | `CalendarDate` | native | 🔌 | ✅ | · | ✅ | ✅ |  | only through the host's own: pickDate on DatePicker: the host's change handler called, not the picker's action; Android Views: cannot read date of DatePicker - Android's driver has no path for it yet |
| `onDateChanged` (`dateChanged`) | event | `CalendarDate` | native | 🔌 | ✅ | · | ✅ | ✅ |  | only through the host's own: pickDate on DatePicker: the host's change handler called, not the picker's action; Android Views: cannot read date of DatePicker - Android's driver has no path for it yet |
| `format` | property | `String` | native |  |  | · | ☑️ | ☑️ |  | not realized; UIKit: not realized; Android Views: cannot read format of DatePicker - Android's driver has no path for it yet; WinUI 3: WinUI writes "D" and "d" in the user's own way, and any other pattern as "d".; GTK 4: GTK writes "D" and "d" in the user's own way, and any other pattern as "d". |
| `isOpen` | property | `Bool` | native |  |  | · | ✅ | ✅ |  | not realized; UIKit: not realized; Android Views: cannot open on DatePicker - Android's driver has no path for it yet |
| `maximumDate` | property | `CalendarDate` | native | ✅ | ✅ | · | ✅ | 🔌 |  | Android Views: cannot read maximumDate of DatePicker - Android's driver has no path for it yet; GTK 4: only through the host's own: read maximumDate of DatePicker: the range the host holds the day in: GtkCalendar holds none |
| `minimumDate` | property | `CalendarDate` | native | ✅ | ✅ | · | ✅ | 🔌 |  | Android Views: cannot read minimumDate of DatePicker - Android's driver has no path for it yet; GTK 4: only through the host's own: read minimumDate of DatePicker: the range the host holds the day in: GtkCalendar holds none |
| `onOpened` (`opened`) | event |  | native |  |  | · | ✅ | ✅ |  | not realized; UIKit: not realized; Android Views: cannot open on DatePicker - Android's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | · |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; GTK 4: cannot read accessibilityHeadingLevel of DatePicker - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityHint of DatePicker - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityLabel of DatePicker - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read automationExcludedWithChildren of DatePicker - GTK's driver has no path for it yet |
| `background` | property | `Background` | native | ☑️ |  | ✅ |  |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  | ✅ | – | – | ✅ | ⏸ |  | UIKit: DatePicker takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: DatePicker takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on DatePicker.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read isAccessibilityHidden of DatePicker - GTK's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `isFocusedChanged` | event | `Bool` | native | ✅ | – | – | ✅ |  |  | UIKit: DatePicker takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: DatePicker takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotX of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotX of DatePicker - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotY of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotY of DatePicker - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read rotation of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read rotation of DatePicker - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationX of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of DatePicker: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationX of DatePicker - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationY of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of DatePicker: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationY of DatePicker - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scale of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scale of DatePicker - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleX of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleX of DatePicker - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleY of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleY of DatePicker - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationX of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationX of DatePicker - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationY of DatePicker: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of DatePicker: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationY of DatePicker - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  | ✅ | – | – | ✅ | ⏸ |  | UIKit: DatePicker takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: DatePicker takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on DatePicker.isFocusedChanged, not realized yet |
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
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off. |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ | 🔌 |  | only through the host's own: pinch on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on DatePicker: the view's listening handed the recognizer's states, no touch sent; GTK 4: only through the host's own: pinch on DatePicker: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: hover on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: pan on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | ✅ |  | only through the host's own: tap on DatePicker: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on DatePicker: the view's listening handed the recognizer's states, no touch sent |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `textColor` | property | `Color` | native | ✅ |  | ✅ | ✅ | · |  | UIKit: not realized; GTK 4: cannot read textColor of DatePicker - GTK's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ |  | ✅ | ✅ | · |  | UIKit: not realized; GTK 4: cannot read fontAttributes of DatePicker - GTK's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native | ✅ |  | · | ✅ | · |  | UIKit: not realized; Android Views: cannot read a family - Android's typeface keeps no family's name; GTK 4: cannot read fontFamily of DatePicker - GTK's driver has no path for it yet |
| `fontSize` | property | `Double` | native | ✅ |  | ✅ | ✅ | · |  | UIKit: not realized; GTK 4: cannot read fontSize of DatePicker - GTK's driver has no path for it yet |
