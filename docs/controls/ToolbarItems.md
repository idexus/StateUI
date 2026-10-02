<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItems

A group of actions a page or an arrangement declares for its bar: one shared background where the platform draws one, joined by the groups of the same id declared further in.

```swift
@State var edited = false

TextEditor()
    .onTextChanged { _ in edited = true }
    .toolbar(.leading) {
        ToolbarItem("New")
    }
    .toolbar {
        ToolbarItem("Save")
            .isEnabled(edited)
            .onClicked { edited = false }
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
<tr><th>Host</th><th>Created</th><th>Members (2)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td>2 ✅</td><td><code>NSToolbarItem</code>; <code>NSMenuToolbarItem</code> overflow</td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td>2 ✅</td><td><code>UIBarButtonItem</code></td></tr>
<tr><td>Android Views</td><td align="center">◐</td><td>1 –</td><td><code>Toolbar</code> <code>MenuItem</code></td></tr>
<tr><td></td><td colspan="3">cannot read the bar of Page - Android's driver has no path for it yet</td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td>2 ✅</td><td><code>CommandBar</code> <code>AppBarButton</code></td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td>2 ✅</td><td><code>GtkButton</code> in <code>GtkHeaderBar</code></td></tr>
<tr><td>Web</td><td align="center"></td><td></td><td><code>&lt;button&gt;</code> in an ARIA <code>toolbar</code></td></tr>
<tr><td></td><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarItemsContract.swift`.

## ToolbarItems's own members

<table>
<tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr>
<tr><td><code>order</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views: cannot read the bar of Page - Android's driver has no path for it yet</td></tr>
<tr><td><code>side</code></td><td>property</td><td><code>ToolbarSide</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td></td></tr>
<tr><td></td><td colspan="9">Android Views: Android's bar has no leading edge beside its navigation button: a leading group stands first among the actions.</td></tr>
</table>
