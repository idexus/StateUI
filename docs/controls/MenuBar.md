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

| Host | Created | Members (1) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 1 ✓ | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ | 1 ✓ | `UIMenu` / `UIAction` |  |
| Android Views | ✅ | 1 ✅ | `PopupMenu` / `MenuItem`; no menu bar |  |
| WinUI 3 | ✅ | 1 ✅ | `MenuFlyout` / `MenuBar` |  |
| GTK 4 | ✅ | 1 ✅ | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` |  |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/MenuBarContract.swift`.

## MenuBar's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `order` | property | `Int` | stateUI | ✓ | ✓ | ✅ | ✅ | ✅ |  | only through the host's own: read the menu of Window: menu items built from the tree at the read, not the main menu; UIKit: only through the host's own: read the menu of Window: the host's menu bar entries, not UIKit's main menu |
