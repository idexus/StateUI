<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SplitView

A page holding two: a sidebar at the side and the page beside it.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/SplitViewContract.swift`.

## SplitView's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isSidebarVisible` | property | `Bool` | native | ✅ | ✅ |  |  |  |  |  |  |
| `isSidebarVisibleChanged` | event | `Bool` | adaptive | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `FlyoutPage`
- **AppKit**: `NSSplitViewController`
- **UIKit**: `UISplitViewController`
- **GTK 4**: `GtkPaned`; libadwaita `AdwOverlaySplitView`
- **Android Views**: AndroidX `DrawerLayout`
- **WinUI 3**: `SplitView`
- **Web**: `<aside>`

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `title` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
