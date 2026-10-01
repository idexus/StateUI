# Map

A map of the world, drawn by the platform's own map, with pins on it. Map is
a component - a library of its own beside StateUI - so an application that
shows no map links neither it nor its platform's map engine.

## Adding it to an application

The application's module imports the map:

```text
Package.swift
  dependencies:  .package(path: "<StateUI>/lib/Controls/Map")
  the module:    .product(name: "StateUIMap", package: "StateUIMap")
```

A map is drawn where the application's head registers the map's backend for
its host. No host has one yet: until it does, the host shows its
unsupported-control marker in the map's place.

## Showing a map

Where a map opens belongs in its initializer - the region around a point,
its radius in meters:

```swift
import StateUIMap

Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
    .mapType(.hybrid)
```

The map pans, so give it room of its own - a Grid row, or a page without a
scroller - rather than a place inside a ScrollView. `isScrollEnabled`,
`isZoomEnabled`, `isTrafficEnabled` and `showsUserLocation` say what the user
may do with it and what it draws. Drawing the user's own position needs the
platform's location permission.

## Pins

The pins on a map are written in `.pins`, where a `Pin` goes and nothing
else. Tapping a pin shows its label and address in the platform's own
callout; `.onPinClicked` hears the tap on the pin, `.onPinDetailsClicked` the
tap on its callout:

```swift
import StateUIMap

@State var chosen = ""

Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
    .pins {
        Pin("Royal Castle")
            .address("Plac Zamkowy 4")
            .type(.place)
            .location(latitude: 52.2479, longitude: 21.0155)
            .onPinClicked { chosen = "castle" }
    }
```

A pin's `type` says what it stands for, which decides the icon the platform
draws. A tap on the map itself, not on a pin, arrives with where it fell:

```swift
import StateUIMap

@State var tapped = "nowhere yet"

Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
    .onMapClicked { place in tapped = "\(place.latitude), \(place.longitude)" }
```

## Moving it

Moving a map that is already shown is an act called through its aim:

```swift
import StateUIMap

@Aim(Map.self) var map

VStack {
    Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
        .aim(map)
        .height(300)
    Button("Old Town")
        .onClicked {
            try await map.moveToRegion(latitude: 52.2497, longitude: 21.0135, radiusMeters: 800)
        }
}
```

## On each platform

| Host | The map |
| --- | --- |
| AppKit | none yet; MapKit's `MKMapView` and `MKAnnotation` are the platform's own |
| UIKit | none yet; MapKit's `MKMapView` and `MKAnnotation` are the platform's own |
| Android Views | none yet; Google Play services' `MapView` needs an API key in the manifest |
| WinUI 3 | none yet; WinUI's `MapControl` needs a map service |
| GTK 4 | none yet; libshumate's `ShumateMap` and `ShumateMarker` draw a tile service's map |
| Web | no map element |

What each host proves stands in the [platform contract's components
table](../../../docs/platform-contract.md#components), read from this
folder's `exports`.
