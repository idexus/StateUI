<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TabView

A page showing several pages, one at a time, with a bar to choose between them.

```swift
struct Tab: View {
    let name: String

    var body: some View {
        Text("Nothing in \(name)").title(name)
    }
}

@State var shown = "Today"

TabView(["Today", "Archive"]) { name in Tab(name: name) }.selection($shown)
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
<thead><tr><th>Host</th><th>Created</th><th>Members (12)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>4 ✅ · 3 ☑️ · 2 ✓ · 2 –</td><td><code>NSTabView</code>: tabless under a full-width select-one <code>NSSegmentedControl</code> beneath the toolbar - the split view detail's <code>NSSplitViewItemAccessoryViewController</code> where the tabbed view stands in a split view's detail, else the title bar's bottom accessory - with top tabs where no window serves it</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>9 ✅ · 1 ✓ · 2 –</td><td><code>UITabBarController</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>7 ✅ · 2 ☑️ · 1 ✓ · 2 –</td><td>custom <code>ViewGroup</code> + <code>LinearLayout</code> tab row</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>8 ✅ · 1 ☑️ · 1 ✓ · 2 –</td><td>custom <code>Panel</code> under a <code>SelectorBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>4 ✅ · 2 ☑️ · 1 ✓ · 4 –</td><td><code>GtkStack</code> + <code>GtkStackSwitcher</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>10 ✅ · 1 ☑️ · 1 ✓</td><td>ARIA <code>tablist</code> of <code>&lt;button&gt;</code> tabs</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/TabViewContract.swift`.

## TabView's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>selectedTab</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read selectedTab of TabView: the host's tab choice, not the tab view's</td></tr></tbody>
<tbody><tr></tr><tr><td><code>selectedTabChanged</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
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
<tbody><tr></tr><tr><td rowspan="2"><code>barBackground</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">✅</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">☑️</td></tr>
<tr><td colspan="9">AppKit: The bars' band is painted under the toolbar's own material: a blur or glass shows its color.<br>Android Views: Android blurs nothing behind a view: a blur or glass shows its color.<br>WinUI 3: WinUI has no glass: a bar of glass shows the in-app acrylic at its fallback thickness. A gradient out from a point is drawn over the bar's box as an ellipse.<br>GTK 4: GNOME blurs nothing inside a window: a blur or glass shows its color. A gradient across a corner or out from a point keeps the header bar's proportions as it was painted, not as the window resizes.<br>Web: A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barForegroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: Only the title takes it, over a band painted in a bar color; the toolbar's items keep the system's color.<br>Android Views: The actions' words take the bar's light or dark theme, as Android's own bars do; the title, the line under it, the navigation button and the pictures take the color itself - on a tab row, the chosen tab's words.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>barScrollEdge</code></td><td>property</td><td><code>ScrollEdge</code></td><td>adaptive</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: No edge: AppKit's toolbar keeps macOS's own edge over what scrolls under it.<br>GTK 4: No edge: GNOME's flat header bar shows its shadow while the content scrolls.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>toolbarStyle</code></td><td>property</td><td><code>ToolbarStyle</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The toolbar's items keep the Mac's own look.<br>UIKit: The bar's buttons keep iOS's own look.<br>Android Views: The toolbar's actions keep Android's own look.<br>WinUI 3: The bar's buttons keep WinUI's own look.<br>GTK 4: The header bar's buttons keep libadwaita's own look.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>toolbarSpacing</code></td><td>property</td><td><code>Double</code></td><td>adaptive</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: The Mac's toolbar draws its items in the Mac's own look.<br>UIKit: A bar's items stand in the system's own look.<br>Android Views: A toolbar's actions stand in Android's own look.<br>WinUI 3: The title bar's commands stand in WinUI's own look.<br>GTK 4: A header bar's buttons stand in libadwaita's own look.</td></tr></tbody>
</table>

## From [PageElement](tiers/PageElement.md)

What a page shows about itself - a title and a picture where another container presents it as an item, and what it stands on - and the links its window is given.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: cannot read background of Page - StateUI draws a page's box on GTK's snapshot, which holds none of its background; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read icon of TabView - AppKit's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onLinkOpened</code> (<code>linkOpened</code>)</td><td>event</td><td><code>String</code></td><td>adaptive</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: openLink on TabView: the host's entry the application's delegate calls, no Apple event sent<br>UIKit: only through the host's own: openLink on TabView: the host's entry the scene's delegate calls, as no URL context can be made<br>Android Views: only through the host's own: openLink on TabView: the host's entry the activity's intent reaches, no intent sent<br>WinUI 3: only through the host's own: openLink on TabView: the relay's report of an activation told the driver's address, no activation<br>GTK 4: only through the host's own: openLink on TabView: the host's entry the application's open signal reaches, no file opened<br>Web: only through the host's own: openLink on TabView: the host's entry the page's address with a fragment reaches, no address loaded</td></tr></tbody>
<tbody><tr></tr><tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>
