<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Divider

A line between entries, grouping the ones above it apart from the ones below.

```swift
Text("Report.pdf")
    .contextMenu {
        MenuItem("Open")
        MenuItem("Rename")
        Divider()
        MenuItem("Delete").isDestructive(true)
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
<thead><tr><th>Host</th><th>Created</th><th>Members (0)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td></td><td><code>NSMenu</code> / <code>NSMenuItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td></td><td><code>UIMenu</code> / <code>UIAction</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td></td><td><code>PopupMenu</code> / <code>MenuItem</code>; no menu bar</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td></td><td><code>MenuFlyout</code> / <code>MenuBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td></td><td><code>GMenu</code> in <code>GtkPopoverMenu</code> / <code>GtkPopoverMenuBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Web</td><td align="center"></td><td></td><td>ARIA <code>menu</code> / <code>menubar</code> (?)</td></tr>
<tr><td colspan="3">no host yet</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/DividerContract.swift`.

## Divider's own members

Divider declares no members of its own.
