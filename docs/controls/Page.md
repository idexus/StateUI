<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Page

What a container shows as a screen: a window's page, a stack's root and destinations, a tab, either half of a split view, a sheet.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PageElement](tiers/PageElement.md)

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · – not planned for that host's family, which meets the contract there - the note says why · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/PageContract.swift`.

## Page's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `appearing` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `backButtonTitle` | property | `String` | adaptive | ✅ |  |  |  |  |  |  |
| `background` | property | `Color` | native | ✅ |  |  | ✅ |  |  |  |
| `disappearing` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `hasBackButton` | property | `Bool` | adaptive | ✅ |  |  | ✅ |  |  |  |
| `hasNavigationBar` | property | `Bool` | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `navigatedFrom` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `navigatedTo` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `navigatingFrom` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `padding` | property | `Insets` | native | ✅ |  |  | ✅ |  |  |  |

Realization:

- **AppKit**: custom `NSView`
- **UIKit**: `UIViewController`
- **GTK 4**: custom `GtkWidget`
- **Android Views**: custom `ViewGroup`
- **WinUI 3**: `Page`
- **Web**: `<section>`

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | ✅ |  |  | ✅ |  |  |  |
| `title` | property | `String` | native | ✅ |  |  | ✅ | ✅ |  |  |
