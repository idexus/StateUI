<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Menu

A menu: a caption and the entries it opens - on the menu bar, or one level down inside another menu.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 2 ✅ of 2 | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ | 1 ✅ · 1 ☑️ of 2 | `UIMenu` / `UIAction` |  |
| Android Views |  |  | `PopupMenu` / `MenuItem`; no menu bar | cannot read the menu of Label - Android's driver has no path for it yet |
| WinUI 3 | ✅ | 2 ✅ of 2 | `MenuFlyout` / `MenuBar` |  |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | no test of it has run yet |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/MenuContract.swift`.

## Menu's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isEnabled` | property | `Bool` | native | ✅ | ☑️ |  | ✅ |  |  | UIKit: UIKit holds no menu out of reach itself: each of its entries is.; Android Views: cannot read the menu of Label - Android's driver has no path for it yet |
| `text` | property | `String` | native | ✅ | ✅ |  | ✅ |  |  | Android Views: cannot read the menu of Label - Android's driver has no path for it yet |
