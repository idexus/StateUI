<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Pin

A pin on the map.

Layer: `provider`. An optional provider supplies it: a package, or the application that registers it with its hosts.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/PinContract.swift`.

## Pin's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `address` | property | `String` | provider | ✅* |  |  |  |  |  |  | MAUI: Windows and Linux have no map; the Map draws the unknown-control marker there. |
| `label` | property | `String` | provider | ✅* |  |  |  |  |  |  | MAUI: Windows and Linux have no map; the Map draws the unknown-control marker there. |
| `location` | property | `Location` | provider | ✅* |  |  |  |  |  |  | MAUI: Windows and Linux have no map; the Map draws the unknown-control marker there. |
| `onPinClicked` (`pinClicked`) | event |  | provider | ✅* |  |  |  |  |  |  | MAUI: Windows and Linux have no map; the Map draws the unknown-control marker there. |
| `onPinDetailsClicked` (`pinDetailsClicked`) | event |  | provider | ✅* |  |  |  |  |  |  | MAUI: Windows and Linux have no map; the Map draws the unknown-control marker there. |
| `type` | property | `PinType` | provider | ✅* |  |  |  |  |  |  | MAUI: Windows and Linux have no map; the Map draws the unknown-control marker there. |

Realization:

- **MAUI**: `Map` / `Pin`
- **AppKit**: `MKMapView` / `MKAnnotation`
- **UIKit**: `MKMapView` / `MKAnnotation`
- **GTK 4**: libshumate `ShumateMap` / `ShumateMarker`
- **Android Views**: Google Play services `MapView` / `Marker` (?)
- **WinUI 3**: `MapControl` (?)
- **Web**: no honest native counterpart.
