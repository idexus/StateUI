<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Page

What a container shows as a screen: a window's page, a stack's root and destinations, a tab, either half of a split view, a sheet.

```swift
struct NotePage: View {
    @Environment private var page: PageSession

    var body: some View {
        Text("Nothing written yet.")
            .onCreated {
                page.title = "Note"
                page.showsBackButton = true
            }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PageElement](tiers/PageElement.md)

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
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>8 ✅</td><td>custom <code>NSView</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>12 ✅</td><td><code>UIViewController</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>7 ✅ · 1 –</td><td>custom <code>ViewGroup</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>10 ✅</td><td><code>Page</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>8 ✅ · 1 –</td><td>custom <code>GtkWidget</code></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td><code>&lt;section&gt;</code></td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/PageContract.swift`.

## Page's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>appearing</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>backButtonTitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read backButtonTitle of Page - AppKit's driver has no path for it yet<br>Android Views: Android's way back in the bar is an arrow, with no words.<br>WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td></td></tr>
<tr><td colspan="9">GTK 4: cannot read background of Page - StateUI draws a page's box on GTK's snapshot, which holds none of its background; its drawing proves it</td></tr></tbody>
<tbody><tr></tr><tr><td><code>disappearing</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>showsBackButton</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center"></td><td align="center"></td><td></td></tr>
<tr><td colspan="9">Android Views: cannot read showsBackButton of Page - Android's driver has no path for it yet<br>WinUI 3, GTK 4: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>showsNavigationBar</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read showsNavigationBar of Page - AppKit's driver has no path for it yet<br>Android Views: cannot read showsNavigationBar of Page - Android's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td><code>navigatedFrom</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>navigatedTo</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>navigatingFrom</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
<tbody><tr></tr><tr><td><code>padding</code></td><td>property</td><td><code>Insets</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
</table>

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read icon of Page - AppKit's driver has no path for it yet<br>Android Views: cannot read icon of Page - Android's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">◐</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: cannot read title of Page - AppKit's driver has no path for it yet<br>Android Views: cannot read title of Page - Android's driver has no path for it yet</td></tr></tbody>
</table>
