<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Page

What a container shows as a screen: a window's page, a stack's root and destinations, a tab, either half of a split view, a sheet.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PageElement](tiers/PageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | custom `NSView` |  |
| UIKit | ⌛ |  | `UIViewController` |  |
| Android Views | ⌛ |  | custom `ViewGroup` |  |
| WinUI 3 | ⌛ |  | `Page` |  |
| GTK 4 |  |  | custom `GtkWidget` | no run of it on these sources |
| Web |  |  | `<section>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/PageContract.swift`.

## Page's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `appearing` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `backButtonTitle` | property | `String` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `background` | property | `Color` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `disappearing` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `hasBackButton` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `hasNavigationBar` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `navigatedFrom` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `navigatedTo` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `navigatingFrom` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `padding` | property | `Insets` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `title` | property | `String` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
