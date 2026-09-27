<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TabbedView

A page showing several pages, one at a time, with a bar to choose between them.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ of 6 | `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it |  |
| UIKit | ✅ | 6 ✅ of 6 | `UITabBarController` |  |
| GTK 4 |  |  | `GtkStack` + `GtkStackSwitcher`; libadwaita `AdwViewStack` | no test of it has run yet |
| Android Views | ✅ | 1 ✅ of 6 | Material Components `BottomNavigationView` (?) |  |
| WinUI 3 | ✅ | 4 ✅ of 6 | `NavigationView` with a top pane |  |
| Web |  |  | ARIA `tablist` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/TabbedViewContract.swift`.

## TabbedView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `currentPage` | property | `Int` | structure | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot choose on TabbedView - Android's driver has no path for it yet |
| `currentPageChanged` | event | `Int` | adaptive | ✅ | ✅ |  |  | ✅ |  | Android Views: cannot choose on TabbedView - Android's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ |  | ✅ | ✅ |  |  |

## From [BarElement](tiers/BarElement.md)

The bar a page arrangement draws: its colour.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive |  | ✅ |  |  |  |  | cannot read barBackgroundColor of TabbedView - AppKit's driver has no path for it yet |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive |  | ✅ |  |  |  |  | cannot read icon of TabbedView - AppKit's driver has no path for it yet; Android Views: cannot read icon of TabbedView - Android's driver has no path for it yet |
| `title` | property | `String` | native |  | ✅ |  |  | ✅ |  | cannot read title of TabbedView - AppKit's driver has no path for it yet; Android Views: cannot read title of TabbedView - Android's driver has no path for it yet |
