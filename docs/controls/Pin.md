<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Pin

A pin on the map.

```swift
@State var chosen = ""

Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
    .pins {
        Pin("Royal Castle")
            .address("Plac Zamkowy 4")
            .location(latitude: 52.2479, longitude: 21.0155)
            .onPinClicked { chosen = "castle" }
    }
```

Layer: `provider`. An optional provider supplies it: a package, or the application that registers it with its hosts.

Inherits nothing: every member below is its own.

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| UIKit |  |  | `MKMapView` / `MKAnnotation` | not realized |
| Android Views | 🧩 | 6 🧩 | the application's own, registered | the application registers its own control |
| WinUI 3 | 🧩 | 6 🧩 | the application's own, registered | the application registers its own control |
| GTK 4 | 🧩 | 6 🧩 | the application's own, registered | the application registers its own control |
| Web |  |  | no honest native counterpart | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/PinContract.swift`.

## Pin's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `address` | property | `String` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `label` | property | `String` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `location` | property | `Location` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPinClicked` (`pinClicked`) | event |  | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `onPinDetailsClicked` (`pinDetailsClicked`) | event |  | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
| `type` | property | `PinType` | provider |  |  | 🧩 | 🧩 | 🧩 |  | not realized; UIKit: not realized; Android Views: the application registers its own control; WinUI 3: the application registers its own control; GTK 4: the application registers its own control |
