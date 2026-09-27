<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TabbedView

A page showing several pages, one at a time, with a bar to choose between them.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ | `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it |  |
| UIKit | ✅ | 6 ✅ | `UITabBarController` |  |
| Android Views | ✅ | 1 ✅ | Material Components `BottomNavigationView` (?) |  |
| WinUI 3 | ⌛ |  | `NavigationView` with a top pane | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkStack` + `GtkStackSwitcher`; libadwaita `AdwViewStack` | no run of it on these sources |
| Web |  |  | ARIA `tablist` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/TabbedViewContract.swift`.

## TabbedView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `currentPage` | property | `Int` | structure | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot choose on TabbedView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `currentPageChanged` | event | `Int` | adaptive | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot choose on TabbedView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [BarElement](tiers/BarElement.md)

The bar a page arrangement draws: its colour.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive | · | ✅ |  | ⌛ |  |  | cannot read barBackgroundColor of TabbedView - AppKit's driver has no path for it yet; Android Views: not realized; WinUI 3: a run of other sources said: not realized |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ⌛ |  |  | cannot read icon of TabbedView - AppKit's driver has no path for it yet; Android Views: cannot read icon of TabbedView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `title` | property | `String` | native | · | ✅ | · | ⌛ |  |  | cannot read title of TabbedView - AppKit's driver has no path for it yet; Android Views: cannot read title of TabbedView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
