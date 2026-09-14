# NavigationStack

A page holding a native stack of pages, with a bar and a back affordance.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/NavigationStack.swift`.

## NavigationStack's own members

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barForegroundColor` | property | ✅ |  |  |  |  |  |  |
| `popped` | handler | ✅ |  |  |  |  |  |  |

Realization:

- **AppKit**: custom `NSView` stack; title, back and actions in the window's `NSToolbar`
- **UIKit**: `UINavigationController`
- **GTK 4**: `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView`
- **Android Views**: custom `ViewGroup` stack + `Toolbar`
- **WinUI 3**: `Frame`
- **Web**: History API

## From [PropertyContainer](tiers/PropertyContainer.md)

Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property |  |  |  |  |  |  |  |

## From [BarElement](tiers/BarElement.md)

The bar over a stack or a set of tabs.

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | ✅ |  |  |  |  |  |  |

## From [PageElement](tiers/PageElement.md)

The identity shown for a constructed container page.

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property |  |  |  |  |  |  |  |
| `title` | property |  |  |  |  |  |  |  |
