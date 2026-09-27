<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SplitView

A page holding two: a sidebar at the side and the page beside it.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ of 5 | `NSSplitViewController` |  |
| UIKit | ✅ | 4 ✅ of 5 | `UISplitViewController` |  |
| Android Views | ✅ | 1 ✅ of 5 | AndroidX `DrawerLayout` |  |
| WinUI 3 | ✅ | 4 ✅ of 5 | `SplitView` |  |
| GTK 4 |  |  | `GtkPaned`; libadwaita `AdwOverlaySplitView` | no test of it has run yet |
| Web |  |  | `<aside>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/SplitViewContract.swift`.

## SplitView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isSidebarVisible` | property | `Bool` | native | ✅ | ✅ |  | ✅ |  |  |  |
| `isSidebarVisibleChanged` | event | `Bool` | adaptive | ✅ |  |  | ✅ |  |  | UIKit: cannot toggle on SplitView - UIKit's driver has no path for it yet; Android Views: its test waits on SplitView.isSidebarVisible, not realized yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  |  |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive |  | ✅ |  |  |  |  | cannot read icon of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read icon of SplitView - Android's driver has no path for it yet |
| `title` | property | `String` | native |  | ✅ |  | ✅ |  |  | cannot read title of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read title of SplitView - Android's driver has no path for it yet |
