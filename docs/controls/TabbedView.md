<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TabbedView

A page showing several pages, one at a time, with a bar to choose between them.

```swift
struct Tab: ContentView {
    let name: String
    @Environment private var page: PageSession

    var content: some View {
        Label("Nothing in \(name)").onCreated { page.title = name }
    }
}

@State var shown = "Today"

TabbedView(["Today", "Archive"]) { name in Tab(name: name) }
    .selection($shown)
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
<tr><th>Host</th><th>Created</th><th>Members (10)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td>5 ✅ · 1 ✓</td><td><code>NSTabView</code>: tabless under a full-width select-one <code>NSSegmentedControl</code> beneath the toolbar - the split view detail's <code>NSSplitViewItemAccessoryViewController</code> on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it</td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>8 ✅ · 2 –</td><td><code>UITabBarController</code></td></tr>
<tr><td>Android Views</td><td align="center">✅</td><td>3 ✅ · 2 –</td><td>custom <code>LinearLayout</code> tab row</td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td>10 ✅</td><td><code>NavigationView</code> with a top pane</td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td>6 ✅ · 4 –</td><td><code>GtkStack</code> + <code>GtkStackSwitcher</code>; libadwaita <code>AdwViewStack</code></td></tr>
<tr><td>Web</td><td align="center"></td><td></td><td>ARIA <code>tablist</code></td></tr>
<tr><td></td><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/TabbedViewContract.swift`.

## TabbedView's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>currentPage</code></td><td>property</td><td><code>Int</code></td><td>structure</td><td align="center">✓</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: read currentPage of TabbedView: the host's tab choice, not the tab view's<br>Android Views: cannot choose on TabbedView - Android's driver has no path for it yet</td></tr>
<tr><td><code>currentPageChanged</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views: cannot choose on TabbedView - Android's driver has no path for it yet</td></tr>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code.</td></tr>
</table>

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>barBackgroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>barForegroundColor</code></td><td>property</td><td><code>Color</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read barForegroundColor of TabbedView - AppKit's driver has no path for it yet<br>Android Views: cannot read barForegroundColor of TabbedView - Android's driver has no path for it yet</td></tr>
<tr><td><code>barIcon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read barIcon of TabbedView - AppKit's driver has no path for it yet<br>UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.<br>Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.<br>GTK 4: A GNOME header bar is its page's own and shows no application's mark.</td></tr>
<tr><td><code>barSubtitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>barTitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.<br>Android Views: An Android bar is its stack's own and names its page; an application names itself in none.<br>GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none.</td></tr>
</table>

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read icon of TabbedView - AppKit's driver has no path for it yet<br>Android Views: cannot read icon of TabbedView - Android's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.</td></tr>
<tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read title of TabbedView - AppKit's driver has no path for it yet<br>Android Views: cannot read title of TabbedView - Android's driver has no path for it yet</td></tr>
</table>
