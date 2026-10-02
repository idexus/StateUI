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

<table>
<tr><th>Host</th><th>Created</th><th>Members (6)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td>6 ✅</td><td><code>MKMapView</code> / <code>MKAnnotation</code></td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>4 ✅ · 2 ✓</td><td><code>MKMapView</code> / <code>MKAnnotation</code></td></tr>
<tr><td>Android Views</td><td align="center">🧩</td><td>6 🧩</td><td>the application's own, registered</td></tr>
<tr><td></td><td colspan="3">the application registers its own control</td></tr>
<tr><td>WinUI 3</td><td align="center">🧩</td><td>6 🧩</td><td>the application's own, registered</td></tr>
<tr><td></td><td colspan="3">the application registers its own control</td></tr>
<tr><td>GTK 4</td><td align="center">🧩</td><td>6 🧩</td><td>the application's own, registered</td></tr>
<tr><td></td><td colspan="3">the application registers its own control</td></tr>
<tr><td>Web</td><td align="center"></td><td></td><td>no honest native counterpart</td></tr>
<tr><td></td><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/PinContract.swift`.

## Pin's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>address</code></td><td>property</td><td><code>String</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr>
<tr><td><code>label</code></td><td>property</td><td><code>String</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr>
<tr><td><code>location</code></td><td>property</td><td><code>Location</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr>
<tr><td><code>onPinClicked</code> (<code>pinClicked</code>)</td><td>event</td><td></td><td>provider</td><td align="center">✅</td><td align="center">✓</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: only through the host's own: open on Pin: the map's delegate told of the callout's button, no touch<br>Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr>
<tr><td><code>onPinDetailsClicked</code> (<code>pinDetailsClicked</code>)</td><td>event</td><td></td><td>provider</td><td align="center">✅</td><td align="center">✓</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: only through the host's own: open on Pin: the map's delegate told of the callout's button, no touch<br>Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr>
<tr><td><code>type</code></td><td>property</td><td><code>PinType</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr>
</table>
