<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# NavigationStack

A page holding a native stack of pages, with a bar and a back affordance.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/NavigationStackContract.swift`.

## NavigationStack's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barForegroundColor` | property | `Color` | adaptive |  |  |  |  |  |  |  |
| `popped` | event | `Int` | adaptive |  |  |  |  |  |  |  |

Realization:

- **AppKit**: custom `NSView` stack; title, back and actions in the window's `NSToolbar`
- **UIKit**: `UINavigationController`
- **GTK 4**: `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView`
- **Android Views**: custom `ViewGroup` stack + `Toolbar`
- **WinUI 3**: `Frame`
- **Web**: History API

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  |  |  |  |

## From [BarElement](tiers/BarElement.md)

The bar a page arrangement draws: its colour.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive |  |  |  |  |  |  |  |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive |  |  |  |  |  |  |  |
| `title` | property | `String` | native |  |  |  |  |  |  |  |
