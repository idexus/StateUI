<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SplitView

A page holding two: a sidebar at the side and the page beside it.

```swift
struct MainPage: View {
    @State private var showsFolders = true

    var body: some View {
        SplitView($showsFolders) {
            Text("Folders")
        } detail: {
            Text("Notes")
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
<thead><tr><th>Host</th><th>Created</th><th>Members (15)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>8 ✅ · 2 ☑️ · 1 ✓ · 3 –</td><td><code>NSSplitViewController</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>10 ✅ · 3 ✓ · 2 –</td><td><code>UISplitViewController</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>5 ✅ · 3 ☑️ · 5 ✓ · 2 –</td><td>custom <code>ViewGroup</code>: a drawer where narrow, beside where wide</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>9 ✅ · 3 ☑️ · 1 ✓ · 2 –</td><td><code>SplitView</code>, the sidebar in its pane: beside the detail from 1008 DIPs, over it where narrower</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>6 ✅ · 1 ☑️ · 3 ✓ · 4 –</td><td><code>AdwOverlaySplitView</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>11 ✅ · 3 ☑️ · 1 ✓</td><td><code>&lt;aside&gt;</code> in a CSS grid: beside the detail from 900px wide, a drawer over it where narrower</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/SplitViewContract.swift`.

## SplitView's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>showsSidebar</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: only through the host's own: read showsSidebar of SplitView: the split's own flag; the drawer slides on it</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>showsSidebarToggle</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: read showsSidebarToggle of SplitView: the visibility the host gave UIKit's own sidebar button, which the split view hands out bare</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>showsSidebarChanged</code></td><td>event</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: only through the host's own: toggle on SplitView: the host's own entry the scrim's tap and the bar's button call</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>sidebarBackground</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">☑️</td><td align="center">✓</td><td align="center">☑️</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: read sidebarBackground of SplitView: the split view's material for a sidebar beside the detail, which an iPhone's room never shows<br>Android Views: only through the host's own: read sidebarBackground of SplitView: the color the split keeps for its sidebar beside the detail, which a phone's room never shows<br>WinUI 3: WinUI has no glass: a pane of glass shows the in-app acrylic at its fallback thickness.<br>GTK 4: only through the host's own: read sidebarBackground of SplitView: the class of the host's style sheet the sidebar wears: GTK reads back no background<br>Web: A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>sidebarOverlayBackground</code></td><td>property</td><td><code>Material</code></td><td>adaptive</td><td align="center">–</td><td align="center">✅</td><td align="center">☑️</td><td align="center">☑️</td><td align="center">✓</td><td align="center">☑️</td></tr>
<tr><td colspan="9">AppKit: A Mac sidebar always stands beside the detail: a window too narrow for both hides it.<br>Android Views: Android blurs nothing behind a view: a blur or glass shows its color.<br>WinUI 3: WinUI has no glass: a pane of glass shows the in-app acrylic at its fallback thickness.<br>GTK 4: only through the host's own: read sidebarOverlayBackground of SplitView: the color the split keeps for its sidebar over the detail, which a wide window never shows<br>Web: A page has no glass: glass is drawn as the blur as clear as it is, a filter under its color.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>sidebarOverlays</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: only through the host's own: read sidebarOverlays of SplitView: the split's own place for the room; the drawer stands by it</td></tr></tbody>
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
<tr><td colspan="9">AppKit: cannot read icon of SplitView - AppKit's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>onLinkOpened</code> (<code>linkOpened</code>)</td><td>event</td><td><code>String</code></td><td>adaptive</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: openLink on SplitView: the host's entry the application's delegate calls, no Apple event sent<br>UIKit: only through the host's own: openLink on SplitView: the host's entry the scene's delegate calls, as no URL context can be made<br>Android Views: only through the host's own: openLink on SplitView: the host's entry the activity's intent reaches, no intent sent<br>WinUI 3: only through the host's own: openLink on SplitView: the relay's report of an activation told the driver's address, no activation<br>GTK 4: only through the host's own: openLink on SplitView: the host's entry the application's open signal reaches, no file opened<br>Web: only through the host's own: openLink on SplitView: the host's entry the page's address with a fragment reaches, no address loaded</td></tr></tbody>
<tbody><tr></tr><tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
</table>
