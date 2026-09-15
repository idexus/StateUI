# MenuItem

One entry in a menu.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/MenuBar.swift`.

## MenuItem's own members

MenuItem declares no members of its own; everything it takes comes from the sections below.

Realization:

- **MAUI**: `MenuFlyout` / `MenuBarItem`
- **AppKit**: `NSMenu` / `NSMenuItem`
- **UIKit**: `UIMenu` / `UIAction`
- **GTK 4**: `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar`
- **Android Views**: `PopupMenu` / `MenuItem`; no menu bar
- **WinUI 3**: `MenuFlyout` / `MenuBar`
- **Web**: ARIA `menu` / `menubar` (?)

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property |  | ✅* |  |  |  |  |  | Only an entry of a context menu carries it; an entry the page puts in the menu bar does not. |

## From [MenuItemElement](tiers/MenuItemElement.md)

What a toolbar item, a menu entry and a swipe action all share: `text`, `icon`, `isDestructive`, `isEnabled` - and `onClicked`, what choosing one does.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | handler | ✅ | ✅ |  |  |  |  |  |  |
| `icon` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isDestructive` | property | ✅ | ✅ |  |  |  |  |  |  |
| `isEnabled` | property | ✅ | ✅ |  |  |  |  |  |  |
| `text` | property | ✅ | ✅ |  |  |  |  |  |  |
