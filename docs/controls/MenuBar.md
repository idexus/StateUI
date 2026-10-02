<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuBar

The menus a page or an arrangement declares for the menu bar, joining the menus of the same id declared around it.

```swift
@State var saved = false

Label(saved ? "Saved" : "Not saved")
    .menuBar {
        Menu("File") {
            MenuItem("Save").onClicked { saved = true }
        }
        .id(StandardMenu.file)
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
<tr><th>Host</th><th>Created</th><th>Members (1)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td>1 ✓</td><td><code>NSMenu</code> / <code>NSMenuItem</code></td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>1 ✓</td><td><code>UIMenu</code> / <code>UIAction</code></td></tr>
<tr><td>Android Views</td><td align="center">✅</td><td>1 ✅</td><td><code>PopupMenu</code> / <code>MenuItem</code>; no menu bar</td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td>1 ✅</td><td><code>MenuFlyout</code> / <code>MenuBar</code></td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td>1 ✅</td><td><code>GMenu</code> in <code>GtkPopoverMenu</code> / <code>GtkPopoverMenuBar</code></td></tr>
<tr><td rowspan="2">Web</td><td align="center"></td><td></td><td>ARIA <code>menu</code> / <code>menubar</code> (?)</td></tr>
<tr><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/MenuBarContract.swift`.

## MenuBar's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td rowspan="2"><code>order</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read the menu of Window: menu items built from the tree at the read, not the main menu<br>UIKit: only through the host's own: read the menu of Window: the host's menu bar entries, not UIKit's main menu</td></tr>
</table>
