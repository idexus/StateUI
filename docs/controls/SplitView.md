<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SplitView

A page holding two: a sidebar at the side and the page beside it.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [PageElement](tiers/PageElement.md)

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

| Host | Created | Members (5) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSSplitViewController` | no run of it on these sources |
| UIKit |  |  | `UISplitViewController` | no run of it on these sources |
| Android Views |  |  | AndroidX `DrawerLayout` | no run of it on these sources |
| WinUI 3 | ✅ | 4 ✅ | `SplitView` |  |
| GTK 4 | ⌛ |  | `GtkPaned`; libadwaita `AdwOverlaySplitView` |  |
| Web |  |  | `<aside>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/SplitViewContract.swift`.

## SplitView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isSidebarVisible` | property | `Bool` | native |  |  |  | ✅ | ⌛ |  |  |
| `isSidebarVisibleChanged` | event | `Bool` | adaptive |  |  |  | ✅ | ⌛ |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive |  |  |  |  |  |  | WinUI 3: not realized; GTK 4: not realized |
| `title` | property | `String` | native |  |  |  | ✅ | · |  | GTK 4: cannot read title of SplitView - GTK's driver has no path for it yet |
