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
| GTK 4 | ✅ | 25 ✅ | composed by StateUI |  |
| Web |  |  | composed by StateUI | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Layouts/GridContract.swift`.

## Grid's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `columnSpacing` | property | `Double` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `columns` | property | `[GridLength]` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `rowSpacing` | property | `Double` | stateUI |  |  |  | ✅ | ✅ |  |  |
| `rows` | property | `[GridLength]` | stateUI |  |  |  | ✅ | ✅ |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityHeadingLevel of Grid - GTK's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityHint of Grid - GTK's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read accessibilityLabel of Grid - GTK's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `background` | property | `Background` | native |  |  |  | ✅ | · |  | GTK 4: cannot read background of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its background; its drawing proves it |
| `focus` | act | `() -> Bool` |  |  |  |  | – | ⏸ |  | WinUI 3: Grid takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on Grid.isFocusedChanged, not realized yet |
| `frame` | property | `Rect` | structure |  |  |  | ✅ | ✅ |  |  |
| `height` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  | ✅ | · |  | GTK 4: cannot read what reaches Grid - GTK's driver has no path for it yet |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | WinUI 3: not realized |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | – |  |  | WinUI 3: Grid takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: not realized |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ | ✅ |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `opacity` | property | `Double` | native |  |  |  | ✅ | ✅ |  |  |
| `pivotX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read pivotX of Grid - GTK's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read pivotY of Grid - GTK's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read rotation of Grid - GTK's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read rotationX of Grid - GTK's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read rotationY of Grid - GTK's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scale of Grid - GTK's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scaleX of Grid - GTK's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read scaleY of Grid - GTK's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  | ✅ | ✅ |  |  |
| `translationX` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read translationX of Grid - GTK's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  | ✅ | · |  | GTK 4: cannot read translationY of Grid - GTK's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | – | ⏸ |  | WinUI 3: Grid takes no keyboard focus here: it refuses it, and nothing is heard; GTK 4: waits on Grid.isFocusedChanged, not realized yet |
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
| `panTouchCount` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  | ✅ | · |  | GTK 4: cannot pinch on Grid - GTK's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Grid - GTK's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Grid - GTK's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Grid - GTK's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Grid - GTK's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  | ✅ | · |  | GTK 4: cannot hover on Grid - GTK's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  | ✅ | · |  | GTK 4: cannot pan on Grid - GTK's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  | ✅ | · |  | GTK 4: cannot tap on Grid - GTK's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot tap on Grid - GTK's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ | ✅ |  |  |

## From [Layout](tiers/Layout.md)

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `clipsContent` | property | `Bool` | native |  |  |  | ✅ | · |  | GTK 4: cannot read clipsContent of Grid - GTK's driver has no path for it yet |
| `letsInputThrough` | property | `Bool` | native |  |  |  |  | · |  | WinUI 3: not realized; GTK 4: cannot read letsInputThrough of Grid - GTK's driver has no path for it yet |

## From [PaddingElement](tiers/PaddingElement.md)

The space kept inside an element, around what it holds.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `padding` | property | `Insets` | native |  |  |  | ✅ | ✅ |  |  |

## From [BorderElement](tiers/BorderElement.md)

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `shape` | property | `ContainerShape` | stateUI |  |  |  | ✅ | · |  | GTK 4: cannot read shape of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its shape; its drawing proves it |
| `stroke` | property | `Brush` | stateUI |  |  |  | ✅ | · |  | GTK 4: cannot read stroke of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its stroke; its drawing proves it |
| `strokeWidth` | property | `Double` | stateUI |  |  |  | ✅ | · |  | GTK 4: cannot read strokeWidth of Grid - StateUI draws a layout's box on GTK's snapshot, which holds none of its strokeWidth; its drawing proves it |
