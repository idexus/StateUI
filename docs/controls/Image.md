<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Image

A picture from the application's resources.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [ImageElement](tiers/ImageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (69) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 24 ✅ · 1 ☑️ | `NSImageView` |  |
| UIKit | ✅ | 24 ✅ | `UIImageView` |  |
| Android Views | ✅ | 49 ✅ | `ImageView` |  |
| WinUI 3 | ⌛ |  | `Image` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkPicture` | no run of it on these sources |
| Web |  |  | `<img>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/ImageContract.swift`.

## Image's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isAnimating` | property | `Bool` | native | · |  |  | ⌛ |  |  | cannot read isAnimating of Image - AppKit's driver has no path for it yet; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `source` | property | `ImageSource` | native | ◐ | ✅ | ◐ | ⌛ |  |  | cannot read source of Image - AppKit's driver has no path for it yet; Android Views: cannot read source of Image - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | · | ⌛ |  |  | cannot read a heading's level: AppKit marks a heading, not its level - AppKit's driver has no path for it yet; UIKit: cannot read a heading's level: UIKit marks a heading, not its level - UIKit's driver has no path for it yet; Android Views: cannot read a heading's level: Android marks a heading, not its level - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `background` | property | `Background` | native | ☑️ |  | ✅ | ⌛ |  |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; WinUI 3: a run of other sources said: not realized |
| `focus` | act | `() -> Bool` |  | · | · | · | ⌛ |  |  | cannot focus Image: it takes no keyboard focus here; UIKit: cannot focus Image: it takes no keyboard focus here; Android Views: cannot focus Image: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `frame` | property | `Rect` | structure | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `ignoresInput` | property | `Bool` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `isEnabled` | property | `Bool` | native |  | · |  | ⌛ |  |  | not realized; UIKit: cannot read isEnabled of Image - UIKit's driver has no path for it yet; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isFocusedChanged` | event | `Bool` | native | · | · | · | ⌛ |  |  | cannot focus Image: it takes no keyboard focus here; UIKit: cannot focus Image: it takes no keyboard focus here; Android Views: cannot focus Image: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `opacity` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `pivotX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read pivotX of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `pivotY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read pivotY of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `rotation` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotation of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `rotationX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotationX of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read rotationY of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: not realized |
| `scale` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scale of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `scaleX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scaleX of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `scaleY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read scaleY of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `style` | property | `Name` | structure |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `translationX` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read translationX of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `translationY` | property | `Double` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: read translationY of Image: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of Image: the host's own transform, checked against the layer it composed itself; WinUI 3: a run of other sources said: ✅ |
| `unfocus` | act | `() -> Void` |  | · | · | · | ⌛ |  |  | cannot focus Image: it takes no keyboard focus here; UIKit: cannot focus Image: it takes no keyboard focus here; Android Views: cannot focus Image: it takes no keyboard focus here; WinUI 3: a run of other sources said: ✅ |
| `width` | property | `Double` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `zIndex` | property | `Int` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `area` | property | `Area` | structure | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `canDrag` | property | `Bool` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `dragStarting` | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `dragText` | property | `String` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  | ⌛ |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `margin` | property | `Insets` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `panTouchCount` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `panXChannel` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `panYChannel` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pinch on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerEntered` (`pointerEntered`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerExited` (`pointerExited`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: hover on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `swipeDirection` | property | `SwipeDirection` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `swipeThreshold` | property | `Double` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: pan on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `tapCount` | property | `Int` | structure | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: tap on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `onTapped` (`tapped`) | event |  | native | 🪞 | 🪞 | ✅ | ⌛ |  |  | only through the host's own: tap on Image: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Image: the view's listening handed the recognizer's states, no touch sent; WinUI 3: a run of other sources said: ✅ |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [ImageElement](tiers/ImageElement.md)

How a picture fills the room it was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ◐ | ◐ | ◐ | ⌛ |  |  | cannot read aspect of Image - AppKit's driver has no path for it yet; UIKit: cannot read aspect of Image - UIKit's driver has no path for it yet; Android Views: cannot read aspect of Image - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
