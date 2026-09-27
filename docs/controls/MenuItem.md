<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItem

One entry in a menu.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ of 6 | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ | 5 ✅ of 6 | `UIMenu` / `UIAction` |  |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | no test of it has run yet |
| Android Views |  |  | `PopupMenu` / `MenuItem`; no menu bar | cannot activate on MenuItem - Android's driver has no path for it yet |
| WinUI 3 | ✅ | 4 ✅ of 6 | `MenuFlyout` / `MenuBar` |  |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/MenuItemContract.swift`.

## MenuItem's own members

MenuItem declares no members of its own.

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of MenuItem - AppKit's driver has no path for it yet; UIKit: cannot read accessibilityIdentifier of MenuItem - UIKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of MenuItem - Android's driver has no path for it yet |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot activate on MenuItem - Android's driver has no path for it yet |
| `icon` | property | `ImageSource` | adaptive |  | ✅ |  |  |  |  | cannot read icon of MenuItem - AppKit's driver has no path for it yet |
| `isDestructive` | property | `Bool` | adaptive |  | ✅ |  |  |  |  | cannot read isDestructive of MenuItem - AppKit's driver has no path for it yet; Android Views: cannot read isDestructive of MenuItem - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot activate on MenuItem - Android's driver has no path for it yet |
| `text` | property | `String` | native | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot read text of MenuItem - Android's driver has no path for it yet |
