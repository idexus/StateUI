<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Menu

A menu: a caption and the entries it opens - on the menu bar, or one level down inside another menu.

```swift
@State var order = "Name"

Text("Sorted by \(order)")
    .menuBar {
        Menu("View") {
            Menu("Sort by") {
                MenuItem("Name").onClicked { order = "Name" }
                MenuItem("Date").onClicked { order = "Date" }
            }
        }
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

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
<thead><tr><th>Host</th><th>Created</th><th>Members (2)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>2 ✅</td><td><code>NSMenu</code> / <code>NSMenuItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>1 ✅ · 1 ☑️</td><td><code>UIMenu</code> / <code>UIAction</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>2 ✅</td><td><code>PopupMenu</code> / <code>MenuItem</code>; no menu bar</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>2 ✅</td><td><code>MenuFlyout</code> / <code>MenuBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>2 ✅</td><td><code>GMenu</code> in <code>GtkPopoverMenu</code> / <code>GtkPopoverMenuBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td>ARIA <code>menu</code> / <code>menubar</code> (?)</td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/MenuContract.swift`.

## Menu's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">UIKit: UIKit holds no menu out of reach itself: each of its entries is.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr></tbody>
</table>
