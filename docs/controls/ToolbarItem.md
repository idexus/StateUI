# ToolbarItem

An action in the page's native navigation or toolbar surface.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/ToolbarItem.swift`.

## ToolbarItem's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `placement` | property |  | ✅ |  |  |  |  |  |  |
| `priority` | property |  | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `ToolbarItem`
- **AppKit**: `NSToolbarItem`; `NSMenuToolbarItem` overflow
- **UIKit**: `UIBarButtonItem`
- **GTK 4**: `GtkButton` in `GtkHeaderBar`
- **Android Views**: `Toolbar` `MenuItem`
- **WinUI 3**: `CommandBar` `AppBarButton`
- **Web**: `<button>` in an ARIA `toolbar`

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property |  |  |  |  |  |  |  |  |

## From [MenuItemElement](tiers/MenuItemElement.md)

What a toolbar item, a menu entry and a swipe action all share: `text`, `icon`, `isDestructive`, `isEnabled` - and `onClicked`, what choosing one does.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | handler |  | ✅ |  |  |  |  |  |  |
| `icon` | property |  | ✅ |  |  |  |  |  |  |
| `isDestructive` | property |  | ✅ |  |  |  |  |  |  |
| `isEnabled` | property |  | ✅ |  |  |  |  |  |  |
| `text` | property |  | ✅ |  |  |  |  |  |  |
