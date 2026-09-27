<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Menu

A menu: a caption and the entries it opens - on the menu bar, or one level down inside another menu.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (2) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 2 ✅ | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ | 1 ✅ · 1 ☑️ | `UIMenu` / `UIAction` |  |
| Android Views | · |  | `PopupMenu` / `MenuItem`; no menu bar | cannot read the menu of Label - Android's driver has no path for it yet |
| WinUI 3 | ⌛ |  | `MenuFlyout` / `MenuBar` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | no run of it on these sources |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/MenuContract.swift`.

## Menu's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isEnabled` | property | `Bool` | native | ✅ | ☑️ | · | ⌛ |  |  | UIKit: UIKit holds no menu out of reach itself: each of its entries is.; Android Views: cannot read the menu of Label - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `text` | property | `String` | native | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot read the menu of Label - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
