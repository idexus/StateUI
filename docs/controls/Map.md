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
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (74) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| UIKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| Android Views | 🧩 | 74 🧩 | the application's own, registered | the application registers its own control |
| WinUI 3 | 🧩 | 74 🧩 | the application's own, registered | the application registers its own control |
| GTK 4 | 🧩 | 74 🧩 | the application's own, registered | the application registers its own control |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/MapContract.swift`.

## Map's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isScrollEnabled` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isTrafficEnabled` | property | `Bool` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isZoomEnabled` | property | `Bool` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onMapClicked` (`mapClicked`) | event | `Location` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `mapType` | property | `MapType` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `moveToRegion` | act | `(Double, Double, Double) -> Void` |  |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `region` | property | `MapRegion` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `showsUserLocation` | property | `Bool` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `accessibilityHint` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `accessibilityLabel` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `background` | property | `Background` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `focus` | act | `() -> Bool` |  |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `frame` | property | `Rect` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `height` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `ignoresInput` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isAccessibilityHidden` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isEnabled` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isFocusedChanged` | event | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isVisible` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `layoutDirection` | property | `LayoutDirection` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `maximumHeight` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `maximumWidth` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `minimumHeight` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `minimumWidth` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `opacity` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `pivotX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `pivotY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `rotation` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `rotationX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `rotationY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `scale` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `scaleX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `scaleY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `style` | property | `Name` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `translationX` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `translationY` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `unfocus` | act | `() -> Void` |  |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `width` | property | `Double` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `zIndex` | property | `Int` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `area` | property | `Area` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `canDrag` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDragOver` (`dragOver`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `dragStarting` | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `dragText` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDrop` (`drop`) | event | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridColumn` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridColumnSpan` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridRow` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridRowSpan` | property | `Int` | stateUI |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `horizontalAlignment` | property | `Alignment` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `margin` | property | `Insets` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `panTouchCount` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `panXChannel` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `panYChannel` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `swipeThreshold` | property | `Double` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `tapCount` | property | `Int` | structure |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onTapped` (`tapped`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `verticalAlignment` | property | `Alignment` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
