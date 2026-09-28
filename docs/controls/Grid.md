<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Grid

Arranges its children in rows and columns.

Layer: `stateUI`. StateUI composes it from smaller primitives before a host receives the tree.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md) · [Layout](tiers/Layout.md) · [PaddingElement](tiers/PaddingElement.md) · [BorderElement](tiers/BorderElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (77) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | custom `NSView` | no run of it on these sources |
| UIKit |  |  | composed by StateUI | no run of it on these sources |
| Android Views |  |  | composed by StateUI | no run of it on these sources |
| WinUI 3 | ✅ | 59 ✅ · 3 – | composed by StateUI |  |
| GTK 4 |  |  | composed by StateUI | no run of it on these sources |
| Web |  |  | composed by StateUI | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/GridContract.swift`.

## Grid's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `columnSpacing` | property | `Double` | stateUI |  |  |  | ✅ |  |  |  |
| `columns` | property | `[GridLength]` | stateUI |  |  |  | ✅ |  |  |  |
| `rowSpacing` | property | `Double` | stateUI |  |  |  | ✅ |  |  |  |
| `rows` | property | `[GridLength]` | stateUI |  |  |  | ✅ |  |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  |  |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  | ✅ |  |  |  |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ |  |  |  |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ |  |  |  |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ |  |  |  |
| `background` | property | `Background` | native |  |  |  | ✅ |  |  |  |
| `focus` | act | `() -> Bool` |  |  |  |  | – |  |  | WinUI 3: Grid takes no keyboard focus here: it refuses it, and nothing is heard |
| `frame` | property | `Rect` | structure |  |  |  | ✅ |  |  |  |
| `height` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  | ✅ |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ |  |  |  |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | – |  |  | WinUI 3: Grid takes no keyboard focus here: it refuses it, and nothing is heard |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ |  |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `opacity` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `pivotY` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `rotation` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `scale` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `scaleX` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `scaleY` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `style` | property | `Name` | structure |  |  |  | ✅ |  |  |  |
| `translationX` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `translationY` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `unfocus` | act | `() -> Void` |  |  |  |  | – |  |  | WinUI 3: Grid takes no keyboard focus here: it refuses it, and nothing is heard |
| `width` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | WinUI 3: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `area` | property | `Area` | structure |  |  |  | ✅ |  |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | WinUI 3: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | WinUI 3: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | WinUI 3: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  |  | ✅ |  |  |  |
| `gridColumn` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `gridColumnSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `gridRow` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `gridRowSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `horizontalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  |  |
| `margin` | property | `Insets` | native |  |  |  | ✅ |  |  |  |
| `panTouchCount` | property | `Int` | structure |  |  |  | ✅ |  |  |  |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  | ✅ |  |  |  |
| `panXChannel` | property | `Int` | structure |  |  |  | ✅ |  |  |  |
| `panYChannel` | property | `Int` | structure |  |  |  | ✅ |  |  |  |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  | ✅ |  |  |  |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  | ✅ |  |  |  |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  | ✅ |  |  |  |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  | ✅ |  |  |  |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  | ✅ |  |  |  |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  | ✅ |  |  |  |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  | ✅ |  |  |  |
| `swipeThreshold` | property | `Double` | structure |  |  |  | ✅ |  |  |  |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  | ✅ |  |  |  |
| `tapCount` | property | `Int` | structure |  |  |  | ✅ |  |  |  |
| `onTapped` (`tapped`) | event |  | native |  |  |  | ✅ |  |  |  |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  |  |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |  |  |  |  |  |  | WinUI 3: not realized |
| `clipsContent` | property | `Bool` | native |  |  |  | ✅ |  |  |  |
| `letsInputThrough` | property | `Bool` | native |  |  |  |  |  |  | WinUI 3: not realized |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native |  |  |  | ✅ |  |  |  |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI |  |  |  | ✅ |  |  |  |
| `stroke` | property | `Brush` | stateUI |  |  |  | ✅ |  |  |  |
| `strokeWidth` | property | `Double` | stateUI |  |  |  | ✅ |  |  |  |
