<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# DatePicker

A day, chosen from the platform's own calendar.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (80) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSDatePicker` | no run of it on these sources |
| UIKit |  |  | `UIDatePicker` | no run of it on these sources |
| Android Views |  |  | `DatePickerDialog` | no run of it on these sources |
| WinUI 3 | ✅ | 63 ✅ · 1 ☑️ | `CalendarDatePicker` |  |
| GTK 4 |  |  | `GtkCalendar` in a `GtkPopover` | not realized |
| Web |  |  | `<input type=date>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/DatePickerContract.swift`.

## DatePicker's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `date` | property | `CalendarDate` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onDateChanged` (`dateChanged`) | event | `CalendarDate` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `format` | property | `String` | native |  |  |  | ☑️ |  |  | WinUI 3: WinUI writes "D" and "d" in the user's own way, and any other pattern as "d".; GTK 4: not realized |
| `isOpen` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `maximumDate` | property | `CalendarDate` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumDate` | property | `CalendarDate` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onOpened` (`opened`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ |  |  | GTK 4: not realized |
| `frame` | property | `Rect` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `height` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `opacity` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `pivotX` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `pivotY` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `rotation` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `scale` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `scaleX` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `scaleY` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `style` | property | `Name` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `translationX` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `translationY` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ |  |  | GTK 4: not realized |
| `width` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridColumn` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridColumnSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridRow` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `gridRowSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  | GTK 4: not realized |
| `horizontalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `margin` | property | `Insets` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `panTouchCount` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `panXChannel` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `panYChannel` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `swipeThreshold` | property | `Double` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `tapCount` | property | `Int` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onTapped` (`tapped`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `textColor` | property | `Color` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `fontSize` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
