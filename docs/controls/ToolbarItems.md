<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItems

A page's toolbar items.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSToolbarItem`; `NSMenuToolbarItem` overflow | no run of it on these sources |
| UIKit |  |  | `UIBarButtonItem` | no run of it on these sources |
| Android Views |  |  | `Toolbar` `MenuItem` | no run of it on these sources |
| WinUI 3 | ✅ |  | `CommandBar` `AppBarButton` |  |
| GTK 4 | · |  | `GtkButton` in `GtkHeaderBar` | cannot activate on ToolbarItem - GTK's driver has no path for it yet |
| Web |  |  | `<button>` in an ARIA `toolbar` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ToolbarItemsContract.swift`.

## ToolbarItems's own members

ToolbarItems declares no members of its own.
