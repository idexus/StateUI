# Menu

A menu: a caption and the entries it opens - on the menu bar, or one level down inside another menu.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/MenuBar.swift`.

## Menu's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isEnabled` | property | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `MenuFlyout` / `MenuBarItem`
- **AppKit**: `NSMenu` / `NSMenuItem`
- **UIKit**: `UIMenu` / `UIAction`
- **GTK 4**: `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar`
- **Android Views**: `PopupMenu` / `MenuItem`; no menu bar
- **WinUI 3**: `MenuFlyout` / `MenuBar`
- **Web**: ARIA `menu` / `menubar` (?)
