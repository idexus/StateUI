<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Pin

A pin on the map.

Layer: `provider`. An optional provider supplies it: a package, or the application that registers it with its hosts.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| UIKit | ⌛ |  | `MKMapView` / `MKAnnotation` | a run of other sources said: not realized |
| Android Views | ⌛ |  | Google Play services `MapView` / `Marker` (?) | a run of other sources said: not realized |
| WinUI 3 | ⌛ |  | `MapControl` (?) | a run of other sources said: not realized |
| GTK 4 |  |  | libshumate `ShumateMap` / `ShumateMarker` | no run of it on these sources |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/PinContract.swift`.

## Pin's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `address` | property | `String` | provider |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `label` | property | `String` | provider |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `location` | property | `Location` | provider |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onPinClicked` (`pinClicked`) | event |  | provider |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onPinDetailsClicked` (`pinDetailsClicked`) | event |  | provider |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `type` | property | `PinType` | provider |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
