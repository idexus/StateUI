<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ZStack

Lays its children one over another, each in the whole room or in the area it names.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/ZStackContract.swift`.

## ZStack's own members

ZStack declares no members of its own.

Realization:

- **AppKit**: custom `NSView`
- **UIKit**: custom `UIView`
- **GTK 4**: `GtkFixed`
- **Android Views**: custom `ViewGroup`
- **WinUI 3**: `Canvas`
- **Web**: `position: absolute`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of ZStack - Android's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  | ✅ |  | cannot read accessibilityHeadingLevel of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHeadingLevel of ZStack - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityHint of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityHint of ZStack - Android's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityLabel of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read accessibilityLabel of ZStack - Android's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read automationExcludedWithChildren of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read automationExcludedWithChildren of ZStack - Android's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  | ✅ |  | cannot read background of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read background of ZStack - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of ZStack - AppKit's driver has no path for it yet |
| `frame` | property | `Rect` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read what reaches ZStack - AppKit's driver has no path for it yet; Android Views: cannot read what reaches ZStack - Android's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read isAccessibilityHidden of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read isAccessibilityHidden of ZStack - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  | ✅ |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ | ✅ |  | cannot read the focus of ZStack - AppKit's driver has no path for it yet |
| `isVisible` | property | `Bool` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotX of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read pivotX of ZStack - Android's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read pivotY of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read pivotY of ZStack - Android's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read rotation of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read rotation of ZStack - Android's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationX of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read rotationX of ZStack - Android's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | cannot read rotationY of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read rotationY of ZStack - Android's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scale of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read scale of ZStack - Android's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleX of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read scaleX of ZStack - Android's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read scaleY of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read scaleY of ZStack - Android's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationX of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read translationX of ZStack - Android's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read translationY of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read translationY of ZStack - Android's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ | ✅ |  | cannot read the focus of ZStack - AppKit's driver has no path for it yet |
| `width` | property | `Double` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  |  |
| `area` | property | `Area` | structure | ✅ |  |  | ✅ | ✅ |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `gridColumn` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `gridRow` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `gridRowSpan` | property | `Int` | stateUI | ✅ |  |  | ✅ | ✅ |  |  |
| `horizontalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `margin` | property | `Insets` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |
| `panTouchCount` | property | `Int` | structure | ☑️ |  |  |  | ✅ |  | AppKit recognises a one-finger pan only; any other `panTouchCount` turns the pan off.; Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot pinch on ZStack - Android's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on ZStack - Android's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on ZStack - Android's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on ZStack - Android's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on ZStack - Android's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot hover on ZStack - Android's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot pan on ZStack - Android's driver has no path for it yet |
| `tapCount` | property | `Int` | structure | ✅ |  |  |  | ✅ |  | Android Views: cannot tap on ZStack - Android's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native | ✅ |  |  |  | ✅ |  | Android Views: cannot tap on ZStack - Android's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native | ✅ |  | ✅ | ✅ | ✅ |  |  |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |  |  |  |  |  |  |  |
| `clipsContent` | property | `Bool` | native |  |  |  |  | ✅ |  | cannot read clipsContent of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read clipsContent of ZStack - Android's driver has no path for it yet |
| `letsInputThrough` | property | `Bool` | native |  |  |  |  |  |  | cannot read letsInputThrough of ZStack - AppKit's driver has no path for it yet |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native | ✅ |  |  | ✅ | ✅ |  |  |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI |  |  |  |  | ✅ |  | cannot read shape of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read shape of ZStack - Android's driver has no path for it yet |
| `stroke` | property | `Brush` | stateUI |  |  |  |  | ✅ |  | cannot read stroke of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read stroke of ZStack - Android's driver has no path for it yet |
| `strokeWidth` | property | `Double` | stateUI |  |  |  |  | ✅ |  | cannot read strokeWidth of ZStack - AppKit's driver has no path for it yet; Android Views: cannot read strokeWidth of ZStack - Android's driver has no path for it yet |
