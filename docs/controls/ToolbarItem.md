<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItem

An action in the page's native navigation or toolbar surface.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (8) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSToolbarItem`; `NSMenuToolbarItem` overflow | no run of it on these sources |
| UIKit |  |  | `UIBarButtonItem` | no run of it on these sources |
| Android Views |  |  | `Toolbar` `MenuItem` | no run of it on these sources |
| WinUI 3 | ✅ | 7 ✅ | `CommandBar` `AppBarButton` |  |
| GTK 4 | · |  | `GtkButton` in `GtkHeaderBar` | cannot activate on ToolbarItem - GTK's driver has no path for it yet |
| Web |  |  | `<button>` in an ARIA `toolbar` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ToolbarItemContract.swift`.

## ToolbarItem's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `placement` | property | `ToolbarItemPlacement` | adaptive |  |  |  | ✅ | · |  | GTK 4: cannot read placement of ToolbarItem - GTK's driver has no path for it yet |
| `priority` | property | `Int` | adaptive |  |  |  | ✅ | · |  | GTK 4: cannot read priority of ToolbarItem - GTK's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native |  |  |  | ✅ | · |  | GTK 4: cannot activate on ToolbarItem - GTK's driver has no path for it yet |
| `icon` | property | `ImageSource` | adaptive |  |  |  | ✅ | · |  | GTK 4: cannot read icon of ToolbarItem - GTK's driver has no path for it yet |
| `isDestructive` | property | `Bool` | adaptive |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  | ✅ | · |  | GTK 4: cannot activate on ToolbarItem - GTK's driver has no path for it yet |
| `text` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read text of ToolbarItem - GTK's driver has no path for it yet |
