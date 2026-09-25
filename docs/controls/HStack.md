<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# HStack

Stacks its children left to right, each as wide as it asks to be.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [StackBase](tiers/StackBase.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/HStackContract.swift`.

## HStack's own members

HStack declares no members of its own.

Realization:

- **AppKit**: custom `NSView`
- **UIKit**: custom `UIView`
- **GTK 4**: `GtkBox`
- **Android Views**: custom `ViewGroup`
- **WinUI 3**: `StackPanel`
- **Web**: flexbox

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  |  |  |  |
| `accessibilityHint` | property | `String` | native |  |  |  |  |  |  |  |
| `accessibilityLabel` | property | `String` | native |  |  |  |  |  |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  |  |  |  |
| `background` | property | `Background` | native |  |  |  |  |  |  |  |
| `focus` | act | `() -> Bool` |  |  |  |  |  |  |  |  |
| `frame` | property | `Rect` | structure |  |  |  |  |  |  |  |
| `height` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  |  |  |  |
| `isEnabled` | property | `Bool` | native |  |  | ✅ |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  |  |  |  |  |
| `isVisible` | property | `Bool` | native |  |  | ✅ |  |  |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `maximumWidth` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `minimumHeight` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `minimumWidth` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `opacity` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  |  |  |  |
| `pivotY` | property | `Double` | native |  |  |  |  |  |  |  |
| `rotation` | property | `Double` | native |  |  |  |  |  |  |  |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  |  |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  |  |
| `scale` | property | `Double` | native |  |  |  |  |  |  |  |
| `scaleX` | property | `Double` | native |  |  |  |  |  |  |  |
| `scaleY` | property | `Double` | native |  |  |  |  |  |  |  |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  |  |  |  |
| `translationY` | property | `Double` | native |  |  |  |  |  |  |  |
| `unfocus` | act | `() -> Void` |  |  |  |  |  |  |  |  |
| `width` | property | `Double` | native |  |  | ✅ |  |  |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  |  |
| `area` | property | `Area` | structure |  |  |  |  |  |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  | ✅ |  |  |  |  |
| `gridColumn` | property | `Int` | stateUI |  |  |  |  |  |  |  |
| `gridColumnSpan` | property | `Int` | stateUI |  |  |  |  |  |  |  |
| `gridRow` | property | `Int` | stateUI |  |  |  |  |  |  |  |
| `gridRowSpan` | property | `Int` | stateUI |  |  |  |  |  |  |  |
| `horizontalAlignment` | property | `Alignment` | native |  |  | ✅ |  |  |  |  |
| `margin` | property | `Insets` | native |  |  | ✅ |  |  |  |  |
| `panTouchCount` | property | `Int` | structure |  |  |  |  |  |  |  |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  |  |  |  |  |
| `panXChannel` | property | `Int` | structure |  |  |  |  |  |  |  |
| `panYChannel` | property | `Int` | structure |  |  |  |  |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  |  |  |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  |  |  |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  |  |  |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  |  |  |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  |  |  |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  |  |  |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  |  |  |  |  |
| `swipeThreshold` | property | `Double` | structure |  |  |  |  |  |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  |  |  |  |  |
| `tapCount` | property | `Int` | structure |  |  |  |  |  |  |  |
| `onTapped` (`tapped`) | event |  | native |  |  |  |  |  |  |  |
| `verticalAlignment` | property | `Alignment` | native |  |  | ✅ |  |  |  |  |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |  |  |  |  |  |  |  |
| `clipsContent` | property | `Bool` | native |  |  |  |  |  |  |  |
| `letsInputThrough` | property | `Bool` | native |  |  |  |  |  |  |  |

## From [StackBase](tiers/StackBase.md)

What both stacks have: the space between their children.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `spacing` | property | `Double` | native |  |  |  |  |  |  |  |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native |  |  |  |  |  |  |  |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI |  |  |  |  |  |  |  |
| `stroke` | property | `Brush` | stateUI |  |  |  |  |  |  |  |
| `strokeWidth` | property | `Double` | stateUI |  |  |  |  |  |  |  |
