<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Image

A picture from the application's resources.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [ImageElement](tiers/ImageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (69) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSImageView` |  |
| UIKit | ⌛ |  | `UIImageView` |  |
| Android Views | ⌛ |  | `ImageView` |  |
| WinUI 3 | ✅ | 50 ✅ · 3 – | `Image` |  |
| GTK 4 |  |  | `GtkPicture` | no run of it on these sources |
| Web |  |  | `<img>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/ImageContract.swift`.

## Image's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isAnimating` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `source` | property | `ImageSource` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `accessibilityHint` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `accessibilityLabel` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `background` | property | `Background` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `focus` | act | `() -> Bool` |  | ⌛ | ⌛ | ⌛ | – |  |  | WinUI 3: Image takes no keyboard focus here: it refuses it, and nothing is heard |
| `frame` | property | `Rect` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `ignoresInput` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | ⌛ | ⌛ | ⌛ | – |  |  | WinUI 3: Image takes no keyboard focus here: it refuses it, and nothing is heard |
| `isVisible` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `layoutDirection` | property | `LayoutDirection` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `opacity` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `pivotX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `pivotY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `rotation` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `rotationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `rotationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `scale` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `scaleX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `scaleY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `style` | property | `Name` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `translationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `translationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `unfocus` | act | `() -> Void` |  | ⌛ | ⌛ | ⌛ | – |  |  | WinUI 3: Image takes no keyboard focus here: it refuses it, and nothing is heard |
| `width` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `zIndex` | property | `Int` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `area` | property | `Area` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `canDrag` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `onDragOver` (`dragOver`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `dragStarting` | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `dragText` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `onDrop` (`drop`) | event | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | WinUI 3: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `gridColumn` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `gridRow` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `margin` | property | `Insets` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `panTouchCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `panXChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `panYChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `swipeThreshold` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `tapCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `onTapped` (`tapped`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
| `verticalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |

## From [ImageElement](tiers/ImageElement.md)

How a picture fills the room it was given.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `aspect` | property | `Aspect` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  |  |
