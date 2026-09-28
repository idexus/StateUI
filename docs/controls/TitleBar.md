<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TitleBar

An authored title area attached to a window.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (70) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | slots in `NSToolbar`; title in a trailing `NSTitlebarAccessoryViewController` | a run of other sources said: · cannot read isVisible of TitleBar - AppKit's driver has no path for it yet |
| UIKit | ⌛ |  | no honest native counterpart | a run of other sources said: not realized |
| Android Views | ⌛ |  | no honest native counterpart | a run of other sources said: not realized |
| WinUI 3 |  |  | `TitleBar` | not realized |
| GTK 4 |  |  | `GtkHeaderBar` | no run of it on these sources |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/TitleBarContract.swift`.

## TitleBar's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barForegroundColor` | property | `Color` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read barForegroundColor of TitleBar - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `icon` | property | `ImageSource` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read icon of TitleBar - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `subtitle` | property | `String` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read subtitle of TitleBar - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `title` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read isVisible of TitleBar - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `accessibilityHint` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `accessibilityLabel` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `background` | property | `Background` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: · cannot read background of TitleBar - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `focus` | act | `() -> Bool` |  | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `frame` | property | `Rect` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `ignoresInput` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isAccessibilityHidden` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `isVisible` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `layoutDirection` | property | `LayoutDirection` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `opacity` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `pivotX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `pivotY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `rotation` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `rotationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `rotationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `scale` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `scaleX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `scaleY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `style` | property | `Name` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `translationX` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `translationY` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `unfocus` | act | `() -> Void` |  | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `width` | property | `Double` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `zIndex` | property | `Int` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `area` | property | `Area` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `canDrag` | property | `Bool` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDragOver` (`dragOver`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `dragStarting` | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `dragText` | property | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDrop` (`drop`) | event | `String` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `gridColumn` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `gridColumnSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `gridRow` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `gridRowSpan` | property | `Int` | stateUI | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `horizontalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `margin` | property | `Insets` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `panTouchCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `panXChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `panYChannel` | property | `Int` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `swipeThreshold` | property | `Double` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `tapCount` | property | `Int` | structure | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `onTapped` (`tapped`) | event |  | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
| `verticalAlignment` | property | `Alignment` | native | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: not realized |
