<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Picker

One choice out of a list.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [TintElement](tiers/TintElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (82) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSPopUpButton` | no run of it on these sources |
| UIKit |  |  | pop-up `UIButton` menu | no run of it on these sources |
| Android Views |  |  | `Spinner` | no run of it on these sources |
| WinUI 3 | ✅ | 65 ✅ | `ComboBox` |  |
| GTK 4 | ✅ | 23 ✅ | `GtkDropDown` |  |
| Web |  |  | `<select>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/PickerContract.swift`.

## Picker's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClosed` (`closed`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isOpen` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `onOpened` (`opened`) | event |  | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `options` | property | `[String]` | structure |  |  |  | ✅ | ✅ |  |  |
| `selectedIndex` | property | `Int` | native |  |  |  | ✅ | ✅ |  |  |
| `onSelectedIndexChanged` (`selectedIndexChanged`) | event | `Int` | native |  |  |  | ✅ | ✅ |  |  |
| `title` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityHeadingLevel of Picker - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityHint of Picker - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityLabel of Picker - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ⏸ |  | GTK 4: waits on Picker.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure |  |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  | ✅ | ✅ |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read pivotX of Picker - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read pivotY of Picker - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read rotation of Picker - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read rotationX of Picker - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read rotationY of Picker - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scale of Picker - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scaleX of Picker - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scaleY of Picker - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read translationX of Picker - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read translationY of Picker - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ⏸ |  | GTK 4: waits on Picker.isFocusedChanged, not realized yet |
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
| `panTouchCount` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  | ✅ | · |  | GTK 4: cannot pinch on Picker - GTK's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Picker - GTK's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Picker - GTK's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Picker - GTK's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Picker - GTK's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Picker - GTK's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  | ✅ | · |  | GTK 4: cannot pan on Picker - GTK's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot tap on Picker - GTK's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot tap on Picker - GTK's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ | ✅ |  |  |

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

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `verticalTextAlignment` | property | `TextAlignment` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |

## From [TintElement](tiers/TintElement.md)

A control's one accent colour.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `tint` | property | `Color` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
