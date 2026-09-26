<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Page

What a container shows as a screen: a window's page, a stack's root and destinations, a tab, either half of a split view, a sheet.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PageElement](tiers/PageElement.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/PageContract.swift`.

## Page's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `appearing` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `backButtonTitle` | property | `String` | adaptive |  |  |  |  |  |  | cannot read backButtonTitle of Page - AppKit's driver has no path for it yet |
| `background` | property | `Color` | native |  |  |  |  | ✅ |  | cannot read background of Page - AppKit's driver has no path for it yet; Android Views: cannot read background of Page - Android's driver has no path for it yet |
| `disappearing` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `hasBackButton` | property | `Bool` | adaptive |  |  |  |  |  |  | cannot read hasBackButton of Page - AppKit's driver has no path for it yet; Android Views: cannot read hasBackButton of Page - Android's driver has no path for it yet |
| `hasNavigationBar` | property | `Bool` | adaptive |  |  |  |  | ✅ |  | cannot read hasNavigationBar of Page - AppKit's driver has no path for it yet; Android Views: cannot read hasNavigationBar of Page - Android's driver has no path for it yet |
| `navigatedFrom` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `navigatedTo` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `navigatingFrom` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `padding` | property | `Insets` | native | ✅ |  |  | ✅ | ✅ |  |  |

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
| `icon` | property | `ImageSource` | adaptive |  |  |  |  |  |  | cannot read icon of Page - AppKit's driver has no path for it yet; Android Views: cannot read icon of Page - Android's driver has no path for it yet |
| `title` | property | `String` | native | ✅ |  |  |  | ✅ |  | Android Views: cannot read title of Page - Android's driver has no path for it yet |
