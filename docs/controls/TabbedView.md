# TabbedView

A page showing several pages, one at a time, with a bar to choose between them.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/TabbedView.swift`.

## TabbedView's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `currentPage` | property | ✅ | ✅ |  |  |  |  |  |  |
| `currentPageChanged` | handler | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `TabbedPage`
- **AppKit**: `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it
- **UIKit**: `UITabBarController`
- **GTK 4**: `GtkStack` + `GtkStackSwitcher`; libadwaita `AdwViewStack`
- **Android Views**: Material Components `BottomNavigationView` (?)
- **WinUI 3**: `NavigationView` with a top pane
- **Web**: ARIA `tablist`

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property |  | ✅ |  |  |  |  |  |  |

## From [BarElement](tiers/BarElement.md)

The bar over a stack or a set of tabs.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | ✅ | ✅ |  |  |  |  |  |  |

## From [PageElement](tiers/PageElement.md)

The identity shown for a constructed container page.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | ✅ | ✅ |  |  |  |  |  |  |
| `title` | property | ✅ | ✅ |  |  |  |  |  |  |
