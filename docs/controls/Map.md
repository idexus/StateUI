<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Map

A map of the world, with pins on it.

```swift
@State var tapped = "nowhere yet"

Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
    .mapType(.hybrid)
    .onMapClicked { place in tapped = "\(place.latitude), \(place.longitude)" }
```

A host with no map of its own shows the one the application registers with it - its control, the provider and the key it needs - and draws the pins as the map's children:

```swift quote
StateUIControls.add(MapContract.self, create: { reports -> MyMap in … }) { map in
    map.property(MapContract.region) { control, region in … }
    map.children(PinContract.self, members: [PinContract.location, PinContract.pinClicked]) { control, pins in
        // each pin: its typed values, and its own reports to raise pinClicked on it
    }
}
```

Layer: `provider`. An optional provider supplies it: a package, or the application that registers it with its hosts.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own backend for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (74) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| UIKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| Android Views | 🧩 | 74 🧩 | the application's own, registered | the application registers its own backend |
| WinUI 3 | 🧩 | 74 🧩 | the application's own, registered | the application registers its own backend |
| GTK 4 | 🧩 | 74 🧩 | the application's own, registered | the application registers its own backend |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/MapContract.swift`.

## Map's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isScrollEnabled` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `isTrafficEnabled` | property | `Bool` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `isZoomEnabled` | property | `Bool` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onMapClicked` (`mapClicked`) | event | `Location` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `mapType` | property | `MapType` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `moveToRegion` | act | `(Double, Double, Double) -> Void` |  |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `region` | property | `MapRegion` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `showsUserLocation` | property | `Bool` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `accessibilityHint` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `accessibilityLabel` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `background` | property | `Background` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `focus` | act | `() -> Bool` |  |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `frame` | property | `Rect` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `height` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `ignoresInput` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `isAccessibilityHidden` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `isEnabled` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `isFocusedChanged` | event | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `isVisible` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `layoutDirection` | property | `LayoutDirection` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `maximumHeight` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `maximumWidth` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `minimumHeight` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `minimumWidth` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `opacity` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `pivotX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `pivotY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `rotation` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `rotationX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `rotationY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `scale` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `scaleX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `scaleY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `style` | property | `Name` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `translationX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `translationY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `unfocus` | act | `() -> Void` |  |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `width` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `zIndex` | property | `Int` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `area` | property | `Area` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `canDrag` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onDragOver` (`dragOver`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `dragStarting` | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `dragText` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onDrop` (`drop`) | event | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `gridColumn` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `gridColumnSpan` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `gridRow` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `gridRowSpan` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `horizontalAlignment` | property | `Alignment` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `margin` | property | `Insets` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `panTouchCount` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `panXChannel` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `panYChannel` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `swipeThreshold` | property | `Double` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `tapCount` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `onTapped` (`tapped`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
| `verticalAlignment` | property | `Alignment` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own backend; WinUI 3: the application registers its own backend; GTK 4: the application registers its own backend |
