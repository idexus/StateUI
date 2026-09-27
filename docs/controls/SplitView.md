<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SplitView

A page holding two: a sidebar at the side and the page beside it.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (5) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 3 ✅ | `NSSplitViewController` |  |
| UIKit | ✅ | 3 ✅ | `UISplitViewController` |  |
| Android Views | ✅ | 1 ✅ | AndroidX `DrawerLayout` |  |
| WinUI 3 | ⌛ |  | `SplitView` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkPaned`; libadwaita `AdwOverlaySplitView` | no run of it on these sources |
| Web |  |  | `<aside>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/SplitViewContract.swift`.

## SplitView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isSidebarVisible` | property | `Bool` | native | ✅ | ◐ | 🪞 | ⌛ |  |  | UIKit: cannot toggle on SplitView - UIKit's driver has no path for it yet; Android Views: only through the host's own: read isSidebarVisible of SplitView: the split's own flag; the drawer slides on it; WinUI 3: a run of other sources said: ✅ |
| `isSidebarVisibleChanged` | event | `Bool` | adaptive | ✅ | · | 🪞 | ⌛ |  |  | UIKit: cannot toggle on SplitView - UIKit's driver has no path for it yet; Android Views: only through the host's own: toggle on SplitView: the host's own entry the scrim's tap and the bar's button call; WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ⌛ |  |  | cannot read icon of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read icon of SplitView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `title` | property | `String` | native | · | ✅ | · | ⌛ |  |  | cannot read title of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read title of SplitView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
