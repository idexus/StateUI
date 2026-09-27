<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# NavigationStack

A page holding a native stack of pages, with a bar and a back affordance.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 1 ✅ | custom `NSView` stack; title, back and actions in the window's `NSToolbar` |  |
| UIKit | ✅ | 6 ✅ | `UINavigationController` |  |
| Android Views | ⌛ |  | custom `ViewGroup` stack + `Toolbar` | a run of other sources said: ✅ |
| WinUI 3 | ⌛ |  | `Frame` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView` | no run of it on these sources |
| Web |  |  | History API | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/NavigationStackContract.swift`.

## NavigationStack's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barForegroundColor` | property | `Color` | adaptive | · | ✅ | ⌛ | ⌛ |  |  | cannot read barForegroundColor of NavigationStack - AppKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read barForegroundColor of NavigationStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `popped` | event | `Int` | adaptive | 🪞 | ✅ | ⌛ | ⌛ |  |  | only through the host's own: goBack on NavigationStack: the host's toolbar or sheet entry called, no toolbar item or sheet touched; Android Views: a run of other sources said: · cannot goBack on NavigationStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ⌛ | ⌛ |  |  | Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |

## From [BarElement](tiers/BarElement.md)

The bar a page arrangement draws: its colour.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive | · | ✅ | ⌛ | ⌛ |  |  | cannot read barBackgroundColor of NavigationStack - AppKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read barBackgroundColor of NavigationStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | ⌛ | ⌛ |  |  | cannot read icon of NavigationStack - AppKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read icon of NavigationStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `title` | property | `String` | native | · | ✅ | ⌛ | ⌛ |  |  | cannot read title of NavigationStack - AppKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read title of NavigationStack - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
