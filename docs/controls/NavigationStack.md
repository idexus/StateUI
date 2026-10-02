<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# NavigationStack

A page holding a native stack of pages, with a bar and a back affordance.

```swift
struct MainWindow: Window {
    @State private var path: [Int] = []

    var page: any Page {
        NavigationStack($path) {
            Button("Open note 1").onClicked { path.append(1) }
        } destination: { note in
            Label("Note \(note)")
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
<tr><th>Host</th><th>Created</th><th>Members (9)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td>4 ✅ · 1 ✓</td><td>custom <code>NSView</code> stack; title, back and actions in the window's <code>NSToolbar</code></td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>7 ✅ · 2 –</td><td><code>UINavigationController</code></td></tr>
<tr><td>Android Views</td><td align="center">✅</td><td>3 ✅ · 2 –</td><td>custom <code>ViewGroup</code> stack + <code>Toolbar</code></td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td>9 ✅</td><td><code>Frame</code></td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td>5 ✅ · 4 –</td><td><code>GtkStack</code> + <code>GtkHeaderBar</code>; libadwaita <code>AdwNavigationView</code></td></tr>
<tr><td>Web</td><td align="center"></td><td></td><td>History API</td></tr>
<tr><td></td><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/NavigationStackContract.swift`.

## NavigationStack's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>popped</code></td><td>event</td><td><code>Int</code></td><td>adaptive</td><td align="center">✓</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: only through the host's own: goBack on NavigationStack: the host's toolbar or sheet entry called, no toolbar item or sheet touched<br>Android Views: cannot goBack on NavigationStack - Android's driver has no path for it yet</td></tr>
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
<tr><td></td><td colspan="9">AppKit: cannot read barForegroundColor of NavigationStack - AppKit's driver has no path for it yet<br>Android Views: cannot read barForegroundColor of NavigationStack - Android's driver has no path for it yet</td></tr>
<tr><td><code>barIcon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read barIcon of NavigationStack - AppKit's driver has no path for it yet<br>UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.<br>Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.<br>GTK 4: A GNOME header bar is its page's own and shows no application's mark.</td></tr>
<tr><td><code>barSubtitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td><code>barTitle</code></td><td>property</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.<br>Android Views: An Android bar is its stack's own and names its page; an application names itself in none.<br>GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none.</td></tr>
</table>

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">–</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read icon of NavigationStack - AppKit's driver has no path for it yet<br>Android Views: cannot read icon of NavigationStack - Android's driver has no path for it yet<br>GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions.</td></tr>
<tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">·</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">AppKit: cannot read title of NavigationStack - AppKit's driver has no path for it yet<br>Android Views: cannot read title of NavigationStack - Android's driver has no path for it yet</td></tr>
</table>
