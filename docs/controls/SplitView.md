# SplitView

A page holding two: a sidebar at the side and the page beside it.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/SplitView.swift`.

## SplitView's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isSidebarVisibleChanged` | handler | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `FlyoutPage`
- **AppKit**: `NSSplitViewController`
- **UIKit**: `UISplitViewController`
- **GTK 4**: `GtkPaned`; libadwaita `AdwOverlaySplitView`
- **Android Views**: AndroidX `DrawerLayout`
- **WinUI 3**: `SplitView`
- **Web**: `<aside>`

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property |  | ✅ |  |  |  |  |  |  |

## From [PageElement](tiers/PageElement.md)

The identity shown for a constructed container page.

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | ✅ | ✅ |  |  |  |  |  |  |
| `title` | property | ✅ | ✅ |  |  |  |  |  |  |
