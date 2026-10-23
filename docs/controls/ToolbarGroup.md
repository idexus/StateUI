<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarGroup

A group of actions a page or a split view declares for its bar - one shared background where the platform draws one - and where it stands: a lone item stands in a group of its own.

```swift
@State var edited = false

TextEditor()
    .onTextChanged { _ in edited = true }
    .toolbar {
        ToolbarButton("New").placement(at: .start)
        ToolbarGroup {
            ToolbarButton("Save")
                .isEnabled(edited)
                .onClicked { edited = false }
            ToolbarButton("Revert")
                .isEnabled(edited)
                .onClicked { edited = false }
        }
        .placement(order: 1)
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
<thead><tr><th>Host</th><th>Created</th><th>Members (5)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>3 ✅</td><td><code>NSToolbarItem</code>; <code>NSMenuToolbarItem</code> overflow</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>3 ✅</td><td><code>UIBarButtonItemGroup</code> / <code>UIBarButtonItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>2 ✅ · 1 ☑️</td><td><code>Toolbar</code> <code>MenuItem</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>3 ✅</td><td><code>CommandBar</code> <code>AppBarButton</code> in the <code>TitleBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>3 ✅</td><td><code>GtkButton</code> in an <code>AdwHeaderBar</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>3 ✅</td><td><code>&lt;button&gt;</code> in an ARIA <code>toolbar</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarGroupContract.swift`.

## ToolbarGroup's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>hidesWithSidebar</code></td><td>property</td><td><code>Bool</code></td><td>stateUI</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isEnabled</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>order</code></td><td>property</td><td><code>Int</code></td><td>stateUI</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>part</code></td><td>property</td><td><code>ToolbarPart</code></td><td>stateUI</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>position</code></td><td>property</td><td><code>ToolbarPosition</code></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">☑️</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">Android Views: Android's bar has no leading edge beside its navigation button: a leading group stands first among the actions.</td></tr></tbody>
</table>
