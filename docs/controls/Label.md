<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Label

A read-only piece of text.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [TextAlignmentElement](tiers/TextAlignmentElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md) · [PaddingElement](tiers/PaddingElement.md)

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

| Host | Created | Members (81) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 38 ✅ · 1 ☑️ · 3 – | `NSTextField` label; `NSAttributedString` runs |  |
| UIKit | ✅ | 39 ✅ · 3 – | `UILabel`; `NSAttributedString` runs |  |
| Android Views | ✅ | 61 ✅ · 1 ☑️ · 3 – | `TextView`; `SpannableString` spans |  |
| WinUI 3 | ✅ | 62 ✅ · 3 – | `TextBlock`; `Run` inlines |  |
| GTK 4 | ✅ | 21 ✅ | `GtkLabel`; `PangoAttrList` runs |  |
| Web |  |  | text element; `<span>` runs | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/LabelContract.swift`.

## Label's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineBreak` | property | `LineBreak` | native | ✅ | ✅ | ✅ | ✅ | ◐ |  | GTK 4: cannot read lineBreak of Label - GTK's driver has no path for it yet |
| `maximumLines` | property | `Int` | native | ✅ | ✅ | ✅ | ✅ | ◐ |  | GTK 4: cannot read maximumLines of Label - GTK's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ✅ | · |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; GTK 4: cannot read accessibilityHeadingLevel of Label - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityHint of Label - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read accessibilityLabel of Label - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read automationExcludedWithChildren of Label - GTK's driver has no path for it yet |
| `background` | property | `Background` | native | ☑️ | ✅ | ✅ | ✅ | · |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; GTK 4: cannot read background of Label - GTK's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  | – | – | – | – | ⏸ |  | Label takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Label takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Label takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Label takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on Label.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  |  |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read isAccessibilityHidden of Label - GTK's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  | ✅ |  |  | ✅ |  | not realized; Android Views: not realized; WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | – | – | – | – |  |  | Label takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Label takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Label takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Label takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotX of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotX of Label - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read pivotY of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read pivotY of Label - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read rotation of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read rotation of Label - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationX of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of Label: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationX of Label - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native | 🔌 | 🔌 | ✅ |  | · |  | only through the host's own: read rotationY of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of Label: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: cannot read rotationY of Label - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scale of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scale of Label - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleX of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleX of Label - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read scaleY of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read scaleY of Label - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationX of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationX of Label - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: read translationY of Label: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of Label: the host's own transform, checked against the layer it composed itself; GTK 4: cannot read translationY of Label - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  | – | – | – | – | ⏸ |  | Label takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Label takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: Label takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: Label takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on Label.isFocusedChanged, not realized yet |
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
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ⌛ | ⌛ |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure | 🔌 | 🔌 | ☑️ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off.; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pinch on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pinch on Label - GTK's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on Label - GTK's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on Label - GTK's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on Label - GTK's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on Label - GTK's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: hover on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot hover on Label - GTK's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: pan on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot pan on Label - GTK's driver has no path for it yet |
| `tapCount` | property | `Int` | structure | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: tap on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot tap on Label - GTK's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native | 🔌 | 🔌 | ✅ | ✅ | · |  | only through the host's own: tap on Label: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Label: the view's listening handed the recognizer's states, no touch sent; GTK 4: cannot tap on Label - GTK's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ | ✅ | ◐ | ✅ | ✅ |  | Android Views: cannot slide on Slider - Android's driver has no path for it yet |
| `textCase` | property | `TextCase` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read characterSpacing of Label - GTK's driver has no path for it yet |
| `textColor` | property | `Color` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read textColor of Label - GTK's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read fontAttributes of Label - GTK's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native | ✅ | ✅ | · | ✅ | · |  | Android Views: cannot read a family - Android's typeface keeps no family's name; GTK 4: cannot read fontFamily of Label - GTK's driver has no path for it yet |
| `fontSize` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read fontSize of Label - GTK's driver has no path for it yet |

## From [TextAlignmentElement](tiers/TextAlignmentElement.md)

Where text sits inside the space its own element was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `horizontalTextAlignment` | property | `TextAlignment` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read horizontalTextAlignment of Label - GTK's driver has no path for it yet |
| `verticalTextAlignment` | property | `TextAlignment` | native | · | · | ✅ | ✅ | · |  | cannot read verticalTextAlignment of Label - AppKit's driver has no path for it yet; UIKit: cannot read verticalTextAlignment of Label - UIKit's driver has no path for it yet; GTK 4: cannot read verticalTextAlignment of Label - GTK's driver has no path for it yet |

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read lineHeight of Label - GTK's driver has no path for it yet |

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `textDecorations` | property | `TextDecorations` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read textDecorations of Label - GTK's driver has no path for it yet |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read padding of Label - GTK's driver has no path for it yet |
