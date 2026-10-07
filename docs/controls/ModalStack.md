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

Inherits: [BarElement](tiers/BarElement.md)

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
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>5 ✅ · 1 ☑️</td><td>sheet <code>NSWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>4 ✅ · 2 –</td><td><code>present(_:animated:)</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>3 ✅ · 1 ☑️ · 2 –</td><td>full-screen <code>Dialog</code> (?)</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>6 ✅</td><td><code>ContentDialog</code> (?)</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>4 ✅ · 2 –</td><td>modal <code>GtkWindow</code>; libadwaita <code>AdwDialog</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>5 ✅ · 1 –</td><td><code>&lt;dialog&gt;</code> with <code>showModal()</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>popped</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>barBackgroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barForegroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: Only the title takes it, over a band painted in a bar colour; the toolbar's items keep the system's colour.<br>Android Views: The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the colour itself - on a tab row, the chosen tab's words.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barIcon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.<br>Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.<br>GTK 4: A GNOME header bar is its page's own and shows no application's mark.<br>Web: A page's bar names its page and the application, and no mark: the browser's tab shows the site's icon.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>barSubtitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barTitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.<br>Android Views: An Android bar is its stack's own and names its page; an application names itself in none.<br>GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none.</td></tr></tbody>
</table>
