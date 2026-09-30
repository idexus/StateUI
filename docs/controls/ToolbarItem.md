<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItem

An action in the page's native navigation or toolbar surface.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (9) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ | 2 ✅ | `NSToolbarItem`; `NSMenuToolbarItem` overflow |  |
| UIKit | ⌛ | 5 ✅ | `UIBarButtonItem` |  |
| Android Views | ⌛ | 1 – | `Toolbar` `MenuItem` |  |
| WinUI 3 | ✅ | 9 ✅ | `CommandBar` `AppBarButton` |  |
| GTK 4 | ⌛ |  | `GtkButton` in `GtkHeaderBar` |  |
| Web |  |  | `<button>` in an ARIA `toolbar` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ToolbarItemContract.swift`.

## ToolbarItem's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `placement` | property | `ToolbarItemPlacement` | adaptive | ⌛ | ⌛ | ⌛ | ✅ | ⌛ |  |  |
| `priority` | property | `Int` | adaptive | ⌛ | ⌛ | ⌛ | ✅ | ⌛ |  |  |
| `showsText` | property | `Bool` | adaptive |  |  |  | ✅ |  |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  | ✅ | – | ✅ |  |  | not realized; Android Views: An Android bar action is a menu entry, which holds no identifier: automation finds it by its title.; GTK 4: not realized |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ | ⌛ |  |  |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ✅ | · |  | cannot read icon of ToolbarItem - AppKit's driver has no path for it yet; Android Views: cannot read icon of ToolbarItem - Android's driver has no path for it yet; GTK 4: cannot read icon of ToolbarItem - GTK's driver has no path for it yet |
| `isDestructive` | property | `Bool` | adaptive |  | ✅ | · | ✅ |  |  | not realized; Android Views: cannot read isDestructive of ToolbarItem - Android's driver has no path for it yet; GTK 4: not realized |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | · | ✅ | · |  | Android Views: cannot activate on ToolbarItem - Android's driver has no path for it yet; GTK 4: cannot activate on ToolbarItem - GTK's driver has no path for it yet |
| `text` | property | `String` | native | ✅ | ✅ | · | ✅ | · |  | Android Views: cannot read text of ToolbarItem - Android's driver has no path for it yet; GTK 4: cannot read text of ToolbarItem - GTK's driver has no path for it yet |
