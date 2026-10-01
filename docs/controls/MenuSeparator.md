<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuSeparator

A line between entries, grouping the ones above it apart from the ones below.

```swift
Label("Report.pdf")
    .contextMenu {
        MenuItem("Open")
        MenuItem("Rename")
        MenuSeparator()
        MenuItem("Delete").isDestructive(true)
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own backend for it with that host. |
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
| AppKit | ✅ |  | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ |  | `UIMenu` / `UIAction` |  |
| Android Views | ✅ |  | `PopupMenu` / `MenuItem`; no menu bar |  |
| WinUI 3 | ✅ |  | `MenuFlyout` / `MenuBar` |  |
| GTK 4 | ✅ |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` |  |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/MenuSeparatorContract.swift`.

## MenuSeparator's own members

MenuSeparator declares no members of its own.
