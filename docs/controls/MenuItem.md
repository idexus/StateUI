<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItem

One entry in a menu.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/MenuItemContract.swift`.

## MenuItem's own members

MenuItem declares no members of its own.

Realization:

- **AppKit**: `NSMenu` / `NSMenuItem`
- **UIKit**: `UIMenu` / `UIAction`
- **GTK 4**: `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar`
- **Android Views**: `PopupMenu` / `MenuItem`; no menu bar
- **WinUI 3**: `MenuFlyout` / `MenuBar`
- **Web**: ARIA `menu` / `menubar` (?)

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  |  |  |  |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native |  |  |  |  |  |  |  |
| `icon` | property | `ImageSource` | adaptive |  |  |  |  |  |  |  |
| `isDestructive` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  |  |
| `text` | property | `String` | native |  |  |  |  |  |  |  |
