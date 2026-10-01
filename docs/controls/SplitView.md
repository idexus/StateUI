<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SplitView

A page holding two: a sidebar at the side and the page beside it.

```swift
struct MainWindow: Window {
    @State private var showsFolders = true

    var page: any Page {
        SplitView($showsFolders) {
            Label("Folders")
        } detail: {
            Label("Notes")
        }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md) · [PageElement](tiers/PageElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (10) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 6 ✅ | `NSSplitViewController` |  |
| UIKit | ✅ | 8 ✅ · 2 – | `UISplitViewController` |  |
| Android Views | ✅ | 3 ✅ · 2 – | custom `ViewGroup`: a drawer where narrow, beside where wide |  |
| WinUI 3 | ✅ | 10 ✅ | `SplitView` |  |
| GTK 4 | ✅ | 6 ✅ · 3 – | `GtkPaned`; libadwaita `AdwOverlaySplitView` |  |
| Web |  |  | `<aside>` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/SplitViewContract.swift`.

## SplitView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `isSidebarVisible` | property | `Bool` | native | ✅ | ✅ | 🔌 | ✅ | ✅ |  | Android Views: only through the host's own: read isSidebarVisible of SplitView: the split's own flag; the drawer slides on it |
| `isSidebarVisibleChanged` | event | `Bool` | adaptive | ✅ | ✅ | 🔌 | ✅ | ✅ |  | Android Views: only through the host's own: toggle on SplitView: the host's own entry the scrim's tap and the bar's button call |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ |  |  | GTK 4: not realized |

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `barForegroundColor` | property | `Color` | adaptive | · | ✅ | · | ✅ | ✅ |  | cannot read barForegroundColor of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read barForegroundColor of SplitView - Android's driver has no path for it yet |
| `barIcon` | property | `ImageSource` | adaptive | · | – | – | ✅ | – |  | cannot read barIcon of SplitView - AppKit's driver has no path for it yet; UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.; Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.; GTK 4: A GNOME header bar is its page's own and shows no application's mark. |
| `barSubtitle` | property | `String` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `barTitle` | property | `String` | adaptive | ✅ | – | – | ✅ | – |  | UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.; Android Views: An Android bar is its stack's own and names its page; an application names itself in none.; GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none. |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ✅ | – |  | cannot read icon of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read icon of SplitView - Android's driver has no path for it yet; GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions. |
| `title` | property | `String` | native | · | ✅ | · | ✅ | ✅ |  | cannot read title of SplitView - AppKit's driver has no path for it yet; Android Views: cannot read title of SplitView - Android's driver has no path for it yet |
