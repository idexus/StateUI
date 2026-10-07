<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# NavigationStack

A page holding a native stack of pages, with a bar and a back affordance.

```swift
struct MainPage: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            Button("Open note 1").onClicked { path.append(1) }
        } destination: { note in
            Text("Note \(note)")
        }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (9)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>4 ✅ · 1 ✓</td><td>custom <code>NSView</code> stack; title, back and actions in the window's <code>NSToolbar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>7 ✅ · 2 –</td><td><code>UINavigationController</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 2 –</td><td>custom <code>ViewGroup</code> stack + <code>Toolbar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>9 ✅</td><td><code>Frame</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>5 ✅ · 4 –</td><td><code>GtkStack</code> + <code>GtkHeaderBar</code>; libadwaita <code>AdwNavigationView</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>7 ✅ · 1 –</td><td>History API</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/NavigationStackContract.swift`.

## NavigationStack's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>popped</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: goBack on NavigationStack: the host's toolbar or sheet entry called, no toolbar item or sheet touched</td></tr></tbody>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr></tbody>
</table>

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>barBackgroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barForegroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read barForegroundColor of NavigationStack - AppKit's driver has no path for it yet<br>Android Views: The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the colour itself - on a tab row, the chosen tab's words.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barIcon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">AppKit: cannot read barIcon of NavigationStack - AppKit's driver has no path for it yet<br>UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.<br>Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.<br>GTK 4: A GNOME header bar is its page's own and shows no application's mark.<br>Web: A page's bar names its page and the application, and no mark: the browser's tab shows the site's icon.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>barSubtitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barTitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.<br>Android Views: An Android bar is its stack's own and names its page; an application names itself in none.<br>GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none.</td></tr></tbody>
</table>

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center"></td></tr>
<tr><td colspan="9">AppKit: cannot read icon of NavigationStack - AppKit's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.<br>Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read title of NavigationStack - AppKit's driver has no path for it yet</td></tr></tbody>
</table>
