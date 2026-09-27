<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Page

What a container shows as a screen: a window's page, a stack's root and destinations, a tab, either half of a split view, a sheet.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PageElement](tiers/PageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 7 ✅ | custom `NSView` |  |
| UIKit | ✅ | 11 ✅ | `UIViewController` |  |
| Android Views | ✅ | 6 ✅ | custom `ViewGroup` |  |
| WinUI 3 | ⌛ |  | `Page` | a run of other sources said: ✅ |
| GTK 4 |  |  | custom `GtkWidget` | no run of it on these sources |
| Web |  |  | `<section>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/PageContract.swift`.

## Page's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `appearing` | event |  | adaptive | ✅ | ✅ | ◐ | ⌛ |  |  | Android Views: cannot goBack on Window - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `backButtonTitle` | property | `String` | adaptive | · |  |  | ⌛ |  |  | cannot read backButtonTitle of Page - AppKit's driver has no path for it yet; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: not realized |
| `background` | property | `Color` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `disappearing` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `hasBackButton` | property | `Bool` | adaptive | · | ✅ | · | ⌛ |  |  | cannot read hasBackButton of Page - AppKit's driver has no path for it yet; Android Views: cannot read hasBackButton of Page - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `hasNavigationBar` | property | `Bool` | adaptive | · | ✅ | · | ⌛ |  |  | cannot read hasNavigationBar of Page - AppKit's driver has no path for it yet; Android Views: cannot read hasNavigationBar of Page - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `navigatedFrom` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `navigatedTo` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `navigatingFrom` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `padding` | property | `Insets` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ⌛ |  |  | cannot read icon of Page - AppKit's driver has no path for it yet; Android Views: cannot read icon of Page - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `title` | property | `String` | native | ◐ | ✅ | · | ⌛ |  |  | cannot read title of Page - AppKit's driver has no path for it yet; Android Views: cannot read title of Page - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
