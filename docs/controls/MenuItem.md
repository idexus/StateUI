<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItem

One entry in a menu.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/MenuItemContract.swift`.

## MenuItem's own members

MenuItem declares no members of its own.

Realization:

- **MAUI**: `MenuFlyout` / `MenuBarItem`
- **AppKit**: `NSMenu` / `NSMenuItem`
- **UIKit**: `UIMenu` / `UIAction`
- **GTK 4**: `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar`
- **Android Views**: `PopupMenu` / `MenuItem`; no menu bar
- **WinUI 3**: `MenuFlyout` / `MenuBar`
- **Web**: ARIA `menu` / `menubar` (?)

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  | ✅* |  |  |  |  |  | Only an entry of a context menu carries it; an entry the page puts in the menu bar does not. |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a reader chooses from has - a menu's entry, a toolbar's item, a swipe's action: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ | ✅ |  |  |  |  |  |  |
| `icon` | property | `ImageSource` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `isDestructive` | property | `Bool` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `text` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
