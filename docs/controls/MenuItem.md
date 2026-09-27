<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItem

One entry in a menu.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ · 1 ☑️ | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ | 6 ✅ | `UIMenu` / `UIAction` |  |
| Android Views | · | 1 – | `PopupMenu` / `MenuItem`; no menu bar | cannot activate on MenuItem - Android's driver has no path for it yet |
| WinUI 3 | ⌛ |  | `MenuFlyout` / `MenuBar` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | no run of it on these sources |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/MenuItemContract.swift`.

## MenuItem's own members

MenuItem declares no members of its own.

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ☑️ | ✅ | – | ⌛ |  |  | Only an entry of a context menu carries it; an entry the page puts in the menu bar does not.; Android Views: An Android menu entry holds no identifier: automation finds it by its title.; WinUI 3: a run of other sources said: ✅ |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot activate on MenuItem - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `icon` | property | `ImageSource` | adaptive | · | ✅ |  | ⌛ |  |  | cannot read icon of MenuItem - AppKit's driver has no path for it yet; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `isDestructive` | property | `Bool` | adaptive | · | ✅ | · | ⌛ |  |  | cannot read isDestructive of MenuItem - AppKit's driver has no path for it yet; Android Views: cannot read isDestructive of MenuItem - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot activate on MenuItem - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `text` | property | `String` | native | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot read text of MenuItem - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
