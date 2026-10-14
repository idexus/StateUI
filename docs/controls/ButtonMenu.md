<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ButtonMenu

The menu a button opens: its entries, shown under the button as a click asks - the whole button's click, or the part of a split button its own action leaves.

```swift
@State var sent = ""

Button("Share").menu {
    MenuItem("Mail").onClicked { sent = "mail" }
    MenuItem("Message").onClicked { sent = "message" }
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
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td></td><td><code>NSComboButton</code>, unified or split</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td></td><td><code>UIButton.menu</code>, opened by a tap or held</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td></td><td><code>PopupMenu</code> at the button, opened by a click or held</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td></td><td><code>DropDownButton</code>, <code>SplitButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td></td><td><code>GtkMenuButton</code>, <code>AdwSplitButton</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td></td><td><code>aria-haspopup</code> button opening an ARIA <code>menu</code>, or held for it</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ButtonMenuContract.swift`.

## ButtonMenu's own members

ButtonMenu declares no members of its own.
