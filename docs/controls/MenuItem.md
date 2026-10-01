<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItem

One entry in a menu.

```swift
@State var archived = false

Label("Report.pdf")
    .contextMenu {
        MenuItem(archived ? "Unarchive" : "Archive")
            .icon("archive.png")
            .onClicked { archived.toggle() }
    }
```

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

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ · 1 ☑️ | `NSMenu` / `NSMenuItem` |  |
| UIKit | ✅ | 6 ✅ | `UIMenu` / `UIAction` |  |
| Android Views | ✅ | 4 ✅ · 2 – | `PopupMenu` / `MenuItem`; no menu bar |  |
| WinUI 3 | ✅ | 4 ✅ | `MenuFlyout` / `MenuBar` |  |
| GTK 4 |  |  | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | not realized |
| Web |  |  | ARIA `menu` / `menubar` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/MenuItemContract.swift`.

## MenuItem's own members

MenuItem declares no members of its own.

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ☑️ | ✅ | – | ✅ |  |  | Only an entry of a context menu carries it; an entry the page puts in the menu bar does not.; Android Views: An Android menu entry holds no identifier: automation finds it by its title.; GTK 4: not realized |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ | ✅ | ✅ | ⌛ | ⌛ |  |  |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | – | ✅ |  |  | cannot read icon of MenuItem - AppKit's driver has no path for it yet; Android Views: Android's menus - a view's context menu, a bar's overflow and its submenus - draw their entries' words alone.; GTK 4: not realized |
| `isDestructive` | property | `Bool` | adaptive | · | ✅ | ✅ | ✅ |  |  | cannot read isDestructive of MenuItem - AppKit's driver has no path for it yet; GTK 4: not realized |
| `isEnabled` | property | `Bool` | native | ✅ | ✅ | ✅ | ⌛ | ⌛ |  |  |
| `text` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |
