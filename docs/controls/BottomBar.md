<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# BottomBar

The view a page stands at its foot, its safe area ending above it.

```swift
@State var draft = ""

Text("Messages")
    .bottomBar {
        TextEditor($draft).growsWithText(true)
    }
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

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
<thead><tr><th>Host</th><th>Created</th><th>Members (1)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>1 ✅</td><td>custom <code>NSView</code> over the page's foot</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>1 ✅</td><td>custom <code>UIView</code> over the page's foot, its edge <code>UIScrollEdgeElementContainerInteraction</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>1 ✅</td><td>custom <code>ViewGroup</code> child of the page, beneath its content</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">⌛</td><td></td><td>custom <code>Panel</code> child of the page, beneath its content</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>1 ☑️</td><td><code>AdwToolbarView</code> bottom bar</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>1 ✅</td><td><code>&lt;div&gt;</code> over the page's foot</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Slots/BottomBarContract.swift`.

## BottomBar's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>edge</code></td><td>property</td><td><code>ScrollEdge</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">⌛</td><td align="center">☑️</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: No edge: GNOME's flat bottom bar shows its shadow while the content scrolls, whatever the edge says.</td></tr></tbody>
</table>
