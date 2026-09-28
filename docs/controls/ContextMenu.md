<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ContextMenu

The menu a view offers where the user asks for one - a secondary click, a long press.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSMenu` / `NSMenuItem` | a run of other sources said: ✅ |
| UIKit | ⌛ |  | `UIMenu` / `UIAction` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `PopupMenu` / `MenuItem`; no menu bar | a run of other sources said: · cannot read the menu of Label - Android's driver has no path for it yet |
| WinUI 3 | ⌛ |  | `MenuFlyout` / `MenuBar` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | no run of it on these sources |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ContextMenuContract.swift`.

## ContextMenu's own members

ContextMenu declares no members of its own.
