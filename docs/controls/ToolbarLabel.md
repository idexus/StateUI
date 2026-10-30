<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarLabel

Words on the page's bar that nobody chooses - how many items, what was last saved.

```swift
@State var unread = 3

Text("Inbox")
    .toolbar(.bottom) {
        ToolbarLabel("\(unread) unread")
            .icon("envelope.png")
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
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>2 ✅</td><td>an <code>NSTextField</code> label as an <code>NSToolbarItem</code>'s view; a disabled <code>NSMenuItem</code> in the overflow</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>2 ✅</td><td>a <code>UIBarButtonItem</code> holding a label, off its shared background; a disabled <code>UIAction</code> in the overflow</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">Android Views</td><td align="center"></td><td></td><td>a <code>TextView</code> as a <code>Toolbar</code> <code>MenuItem</code>'s action view</td></tr>
<tr><td colspan="3">no run of it on these sources</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">WinUI 3</td><td align="center"></td><td></td><td>a <code>TextBlock</code> in a <code>CommandBar</code>'s <code>AppBarElementContainer</code></td></tr>
<tr><td colspan="3">no run of it on these sources</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2">GTK 4</td><td align="center"></td><td></td><td>a <code>GtkLabel</code> in an <code>AdwHeaderBar</code> or a <code>GtkActionBar</code></td></tr>
<tr><td colspan="3">no run of it on these sources</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>2 ✅</td><td><code>&lt;span&gt;</code> in an ARIA <code>toolbar</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarLabelContract.swift`.

## ToolbarLabel's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>icon</code></td><td>property</td><td><code>ImageSource</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center">✅</td></tr></tbody>
</table>
