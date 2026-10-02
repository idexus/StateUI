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
| AppKit | ✅ | 33 ✅ · 1 ☑️ · 26 ✓ · 3 – | `MKMapView` / `MKAnnotation` |  |
| UIKit | ✅ | 33 ✅ · 26 ✓ · 3 – | `MKMapView` / `MKAnnotation` |  |
| Android Views | 🧩 | 74 🧩 | the application's own, registered | the application registers its own control |
| WinUI 3 | 🧩 | 74 🧩 | the application's own, registered | the application registers its own control |
| GTK 4 | 🧩 | 74 🧩 | the application's own, registered | the application registers its own control |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/MapContract.swift`.

## Map's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isScrollEnabled` | property | `Bool` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isTrafficEnabled` | property | `Bool` | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isZoomEnabled` | property | `Bool` | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onMapClicked` (`mapClicked`) | event | `Location` | provider | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: tap on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `mapType` | property | `MapType` | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `moveToRegion` | act | `(Double, Double, Double) -> Void` |  | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `region` | property | `MapRegion` | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `showsUserLocation` | property | `Bool` | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native | · | · | 🧩 | 🧩 | 🧩 |  | cannot read a heading's level - AppKit marks a heading, not its level; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `accessibilityHint` | property | `String` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `accessibilityLabel` | property | `String` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `automationExcludedWithChildren` | property | `Bool` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `background` | property | `Background` | native | ☑️ |  | 🧩 | 🧩 | 🧩 |  | AppKit paints a colour on this view; a brush is drawn only by a layout.; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `focus` | act | `() -> Bool` |  | – | – | 🧩 | 🧩 | 🧩 |  | Map takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Map takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `frame` | property | `Rect` | structure | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `height` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `ignoresInput` | property | `Bool` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isAccessibilityHidden` | property | `Bool` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isEnabled` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isFocusedChanged` | event | `Bool` | native | – | – | 🧩 | 🧩 | 🧩 |  | Map takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Map takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `isVisible` | property | `Bool` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `layoutDirection` | property | `LayoutDirection` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `opacity` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `pivotX` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read pivotX of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotX of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `pivotY` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read pivotY of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read pivotY of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `rotation` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read rotation of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotation of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `rotationX` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read rotationX of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationX of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `rotationY` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read rotationY of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read rotationY of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `scale` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read scale of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scale of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `scaleX` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read scaleX of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleX of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `scaleY` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read scaleY of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read scaleY of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `style` | property | `Name` | structure | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `translationX` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read translationX of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationX of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `translationY` | property | `Double` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: read translationY of Map: the host's own transform, checked against the layer it composed itself; UIKit: only through the host's own: read translationY of Map: the host's own transform, checked against the layer it composed itself; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `unfocus` | act | `() -> Void` |  | – | – | 🧩 | 🧩 | 🧩 |  | Map takes no keyboard focus here: it refuses it, and nothing is heard; UIKit: Map takes no keyboard focus here: it refuses it, and nothing is heard; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `width` | property | `Double` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `zIndex` | property | `Int` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `area` | property | `Area` | structure | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `canDrag` | property | `Bool` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDragOver` (`dragOver`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `dragStarting` | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `dragText` | property | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDrop` (`drop`) | event | `String` | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridColumn` | property | `Int` | stateUI | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridColumnSpan` | property | `Int` | stateUI | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridRow` | property | `Int` | stateUI | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `gridRowSpan` | property | `Int` | stateUI | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `horizontalAlignment` | property | `Alignment` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `margin` | property | `Insets` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `panTouchCount` | property | `Int` | structure | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `panXChannel` | property | `Int` | structure | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `panYChannel` | property | `Int` | structure | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pinch on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pinch on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerEntered` (`pointerEntered`) | event |  | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: hover on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerExited` (`pointerExited`) | event |  | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: hover on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: hover on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: hover on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: hover on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: hover on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `swipeDirection` | property | `SwipeDirection` | structure | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `swipeThreshold` | property | `Double` | structure | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: pan on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: pan on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `tapCount` | property | `Int` | structure | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: tap on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onTapped` (`tapped`) | event |  | native | ✓ | ✓ | 🧩 | 🧩 | 🧩 |  | only through the host's own: tap on Map: handed to the host's recognizer or handler, no NSEvent sent; UIKit: only through the host's own: tap on Map: the view's listening handed the recognizer's states, no touch sent; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `verticalAlignment` | property | `Alignment` | native | ✅ | ✅ | 🧩 | 🧩 | 🧩 |  | Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
