<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Pin

A pin on the map.

Layer: `provider`. An optional provider supplies it: a package, or the application that registers it with its hosts.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| UIKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| GTK 4 |  |  | libshumate `ShumateMap` / `ShumateMarker` | no test of it has run yet |
| Android Views |  |  | Google Play services `MapView` / `Marker` (?) | not realized |
| WinUI 3 |  |  | `MapControl` (?) | not realized |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/PinContract.swift`.

## Pin's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `address` | property | `String` | provider |  |  |  |  |  |  |  |
| `label` | property | `String` | provider |  |  |  |  |  |  |  |
| `location` | property | `Location` | provider |  |  |  |  |  |  |  |
| `onPinClicked` (`pinClicked`) | event |  | provider |  |  |  |  |  |  |  |
| `onPinDetailsClicked` (`pinDetailsClicked`) | event |  | provider |  |  |  |  |  |  |  |
| `type` | property | `PinType` | provider |  |  |  |  |  |  |  |
