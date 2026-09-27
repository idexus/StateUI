<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItem

An action in the page's native navigation or toolbar surface.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ToolbarItemContract.swift`.

## ToolbarItem's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `placement` | property | `ToolbarItemPlacement` | adaptive |  |  |  |  | ✅ |  | cannot read placement of ToolbarItem - AppKit's driver has no path for it yet; UIKit: cannot read placement of ToolbarItem - UIKit's driver has no path for it yet; Android Views: cannot read placement of ToolbarItem - Android's driver has no path for it yet |
| `priority` | property | `Int` | adaptive |  |  |  |  | ✅ |  | cannot read priority of ToolbarItem - AppKit's driver has no path for it yet; UIKit: cannot read priority of ToolbarItem - UIKit's driver has no path for it yet; Android Views: cannot read priority of ToolbarItem - Android's driver has no path for it yet |

Realization:

- **AppKit**: `NSToolbarItem`; `NSMenuToolbarItem` overflow
- **UIKit**: `UIBarButtonItem`
- **GTK 4**: `GtkButton` in `GtkHeaderBar`
- **Android Views**: `Toolbar` `MenuItem`
- **WinUI 3**: `CommandBar` `AppBarButton`
- **Web**: `<button>` in an ARIA `toolbar`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  | ✅ |  | cannot read accessibilityIdentifier of ToolbarItem - AppKit's driver has no path for it yet; UIKit: cannot read accessibilityIdentifier of ToolbarItem - UIKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of ToolbarItem - Android's driver has no path for it yet |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot activate on ToolbarItem - Android's driver has no path for it yet |
| `icon` | property | `ImageSource` | adaptive |  | ✅ |  |  |  |  | cannot read icon of ToolbarItem - AppKit's driver has no path for it yet; Android Views: cannot read icon of ToolbarItem - Android's driver has no path for it yet |
| `isDestructive` | property | `Bool` | adaptive |  | ✅ |  |  |  |  | Android Views: cannot read isDestructive of ToolbarItem - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot activate on ToolbarItem - Android's driver has no path for it yet |
| `text` | property | `String` | native |  | ✅ |  |  | ✅ |  | cannot read text of ToolbarItem - AppKit's driver has no path for it yet; Android Views: cannot read text of ToolbarItem - Android's driver has no path for it yet |
