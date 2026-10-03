<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ModalStack

An arrangement presenting pages over the page it holds: its first child is that page, the others the sheets over it, the last on top.

```swift
struct MainPage: View {
    @State private var sheets: [String] = []

    var body: some View {
        ModalStack($sheets) {
            Button("Settings").onClicked { sheets.append("Settings") }
        } destination: { sheet in
            Button("Close \(sheet)").onClicked { sheets.removeLast() }
        }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (7)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>4 ✅</td><td>sheet <code>NSWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>4 ✅ · 2 –</td><td><code>present(_:animated:)</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>3 ✅ · 2 –</td><td>full-screen <code>Dialog</code> (?)</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>6 ✅</td><td><code>ContentDialog</code> (?)</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>4 ✅ · 3 –</td><td>modal <code>GtkWindow</code>; libadwaita <code>AdwDialog</code></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td><code>&lt;dialog&gt;</code> with <code>showModal()</code></td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>popped</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">·</td><td align="center">·</td><td align="center">·</td><td align="center"></td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read accessibilityIdentifier of ModalStack - AppKit's driver has no path for it yet<br>UIKit: cannot read accessibilityIdentifier of ModalStack - UIKit's driver has no path for it yet<br>Android Views: cannot read accessibilityIdentifier of ModalStack - Android's driver has no path for it yet<br>WinUI 3: not realized<br>GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr></tbody>
</table>

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>barBackgroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barForegroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read barForegroundColor of ModalStack - AppKit's driver has no path for it yet<br>Android Views: cannot read barForegroundColor of ModalStack - Android's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barIcon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read barIcon of ModalStack - AppKit's driver has no path for it yet<br>UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.<br>Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.<br>GTK 4: A GNOME header bar is its page's own and shows no application's mark.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>barSubtitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barTitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.<br>Android Views: An Android bar is its stack's own and names its page; an application names itself in none.<br>GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none.</td></tr></tbody>
</table>
