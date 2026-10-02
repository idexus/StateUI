<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Marker

A marker on the map.

```swift
@State var chosen = ""

Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
    .markers {
        Marker("Royal Castle")
            .subtitle("Plac Zamkowy 4")
            .location(latitude: 52.2479, longitude: 21.0155)
            .onSelected { chosen = "castle" }
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
<thead><tr><th>Host</th><th>Created</th><th>Members (6)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>6 ✅</td><td><code>MKMapView</code> / <code>MKAnnotation</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>4 ✅ · 2 ✓</td><td><code>MKMapView</code> / <code>MKAnnotation</code></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Android Views</td><td align="center">🧩</td><td>6 🧩</td><td>the application's own, registered</td></tr>
<tr><td colspan="3">the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">WinUI 3</td><td align="center">🧩</td><td>6 🧩</td><td>the application's own, registered</td></tr>
<tr><td colspan="3">the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">GTK 4</td><td align="center">🧩</td><td>6 🧩</td><td>the application's own, registered</td></tr>
<tr><td colspan="3">the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td>no honest native counterpart</td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/MarkerContract.swift`.

## Marker's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>onDetailsClicked</code> (<code>detailsClicked</code>)</td><td>event</td><td></td><td>provider</td><td align="center">✅</td><td align="center">✓</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td colspan="9">UIKit: only through the host's own: open on Marker: the map's delegate told of the callout's button, no touch<br>Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>label</code></td><td>property</td><td><code>String</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>location</code></td><td>property</td><td><code>Location</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onSelected</code> (<code>selected</code>)</td><td>event</td><td></td><td>provider</td><td align="center">✅</td><td align="center">✓</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td colspan="9">UIKit: only through the host's own: open on Marker: the map's delegate told of the callout's button, no touch<br>Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>subtitle</code></td><td>property</td><td><code>String</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>type</code></td><td>property</td><td><code>MarkerType</code></td><td>provider</td><td align="center">✅</td><td align="center">✅</td><td align="center">🧩</td><td align="center">🧩</td><td align="center">🧩</td><td></td></tr>
<tr><td colspan="9">Android Views, WinUI 3, GTK 4: the application registers its own control</td></tr></tbody>
</table>
