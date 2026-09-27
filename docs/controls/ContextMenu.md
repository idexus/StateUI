<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ContextMenu

The menu a view offers where the user asks for one - a secondary click, a long press.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ |  | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ |  | `UIMenu` / `UIAction` |  |
| Android Views |  |  | `PopupMenu` / `MenuItem`; no menu bar | cannot read the menu of Label - Android's driver has no path for it yet |
| WinUI 3 | ✅ |  | `MenuFlyout` / `MenuBar` |  |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | no test of it has run yet |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ContextMenuContract.swift`.

## ContextMenu's own members

ContextMenu declares no members of its own.
