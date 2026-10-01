<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# NavigationStack

A page holding a native stack of pages, with a bar and a back affordance.

```swift
struct MainWindow: Window {
    @State private var path: [Int] = []

    var page: any Page {
        NavigationStack($path) {
            Button("Open note 1").onClicked { path.append(1) }
        } destination: { note in
            Label("Note \(note)")
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
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (9) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 4 ✅ | custom `NSView` stack; title, back and actions in the window's `NSToolbar` |  |
| UIKit | ✅ | 7 ✅ · 2 – | `UINavigationController` |  |
| Android Views | ✅ | 3 ✅ · 2 – | custom `ViewGroup` stack + `Toolbar` |  |
| WinUI 3 | ✅ | 9 ✅ | `Frame` |  |
| GTK 4 | ✅ | 5 ✅ · 4 – | `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView` |  |
| Web |  |  | History API | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Navigation/NavigationStackContract.swift`.

## NavigationStack's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `popped` | event | `Int` | adaptive | 🔌 | ✅ | · | ✅ | ✅ |  | only through the host's own: goBack on NavigationStack: the host's toolbar or sheet entry called, no toolbar item or sheet touched; Android Views: cannot goBack on NavigationStack - Android's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ | ✅ | ✅ | ✅ | – |  | GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code. |

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `barForegroundColor` | property | `Color` | adaptive | · | ✅ | · | ✅ | ✅ |  | cannot read barForegroundColor of NavigationStack - AppKit's driver has no path for it yet; Android Views: cannot read barForegroundColor of NavigationStack - Android's driver has no path for it yet |
| `barIcon` | property | `ImageSource` | adaptive | · | – | – | ✅ | – |  | cannot read barIcon of NavigationStack - AppKit's driver has no path for it yet; UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.; Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.; GTK 4: A GNOME header bar is its page's own and shows no application's mark. |
| `barSubtitle` | property | `String` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `barTitle` | property | `String` | adaptive | ✅ | – | – | ✅ | – |  | UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.; Android Views: An Android bar is its stack's own and names its page; an application names itself in none.; GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none. |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ✅ | – |  | cannot read icon of NavigationStack - AppKit's driver has no path for it yet; Android Views: cannot read icon of NavigationStack - Android's driver has no path for it yet; GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions. |
| `title` | property | `String` | native | · | ✅ | · | ✅ | ✅ |  | cannot read title of NavigationStack - AppKit's driver has no path for it yet; Android Views: cannot read title of NavigationStack - Android's driver has no path for it yet |
