<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItem

An action in the page's native navigation or toolbar surface.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (8) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSToolbarItem`; `NSMenuToolbarItem` overflow | a run of other sources said: 🪞 only through the host's own: activate on ToolbarItem: the host's toolbar entry called, no toolbar item touched |
| UIKit | ⌛ |  | `UIBarButtonItem` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `Toolbar` `MenuItem` | a run of other sources said: · cannot activate on ToolbarItem - Android's driver has no path for it yet |
| WinUI 3 | ✅ | 7 ✅ | `CommandBar` `AppBarButton` |  |
| GTK 4 |  |  | `GtkButton` in `GtkHeaderBar` | no run of it on these sources |
| Web |  |  | `<button>` in an ARIA `toolbar` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ToolbarItemContract.swift`.

## ToolbarItem's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `placement` | property | `ToolbarItemPlacement` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read placement of ToolbarItem - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read placement of ToolbarItem - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read placement of ToolbarItem - Android's driver has no path for it yet |
| `priority` | property | `Int` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read priority of ToolbarItem - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read priority of ToolbarItem - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read priority of ToolbarItem - Android's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: – An Android bar action is a menu entry, which holds no identifier: automation finds it by its title. |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: activate on ToolbarItem: the host's toolbar entry called, no toolbar item touched; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot activate on ToolbarItem - Android's driver has no path for it yet |
| `icon` | property | `ImageSource` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read icon of ToolbarItem - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read icon of ToolbarItem - Android's driver has no path for it yet |
| `isDestructive` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ |  |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read isDestructive of ToolbarItem - Android's driver has no path for it yet; WinUI 3: not realized |
| `isEnabled` | property | `Bool` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot activate on ToolbarItem - Android's driver has no path for it yet |
| `text` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read text of ToolbarItem - Android's driver has no path for it yet |
