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

Inherits: [AutomationElement](tiers/AutomationElement.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

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
<thead><tr><th>Host</th><th>Created</th><th>Members (8)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>2 ✅ · 2 ☑️ · 1 ✓ · 2 –</td><td>custom <code>NSView</code> stack; title, back and actions in the window's <code>NSToolbar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>6 ✅ · 2 –</td><td><code>UINavigationController</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>4 ✅ · 2 ☑️ · 2 –</td><td>custom <code>ViewGroup</code> stack + <code>Toolbar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>5 ✅ · 1 ☑️ · 2 –</td><td>custom <code>Panel</code> stack; title, back and actions in the window's <code>TitleBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>3 ✅ · 1 ✓ · 4 –</td><td><code>AdwNavigationView</code> of <code>AdwNavigationPage</code>s</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>7 ✅ · 1 ☑️</td><td><code>&lt;div&gt;</code> stack; one History API entry to go back</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/NavigationStackContract.swift`.

## NavigationStack's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>popped</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: goBack on NavigationStack: the host's toolbar or sheet entry called, no toolbar item or sheet touched</td></tr></tbody>
</table>

## From [AutomationElement](tiers/AutomationElement.md)

What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: GTK 4 tells assistive technology no identifier before 4.22, and from 4.22 only a GtkBuilder file's id, which no public call sets on a widget made in code.</td></tr></tbody>
</table>

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its look.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>barBackground</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">✅</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">✓</td><td align="center">☑️</td></tr>
<tr><td colspan="9">AppKit: The bars' band is painted under the toolbar's own material: a blur or glass shows its color.<br>Android Views: Android blurs nothing behind a view: a blur or glass shows its color.<br>WinUI 3: WinUI has no glass: a bar of glass shows the in-app acrylic at its fallback thickness.<br>GTK 4: only through the host's own: read barBackground of NavigationStack: the class of the host's style sheet the header wears: GTK reads back no background<br>Web: A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barButtonBackgroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: A toolbar item stands in the Mac's own look, with no background of the application's.<br>UIKit: A bar button stands in the system's glass, which takes no color of the application's.<br>Android Views: A toolbar's action is Android's own, with no background of the application's.<br>WinUI 3: An app bar button is WinUI's own, with no background of the application's.<br>GTK 4: A header bar's buttons are libadwaita's own, flat.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barForegroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: Only the title takes it, over a band painted in a bar color; the toolbar's items keep the system's color.<br>Android Views: The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the color itself - on a tab row, the chosen tab's words.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>toolbarStyle</code></td><td>property</td><td><code>ToolbarStyle</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The toolbar's items keep the Mac's own look.<br>UIKit: The bar's buttons keep iOS's own look.<br>Android Views: The toolbar's actions keep Android's own look.<br>WinUI 3: The bar's buttons keep WinUI's own look.<br>GTK 4: The header bar's buttons keep libadwaita's own look.</td></tr></tbody>
</table>

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read icon of NavigationStack - AppKit's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>
