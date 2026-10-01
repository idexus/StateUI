<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ModalStack

An arrangement presenting pages over the page it holds: its first child is that page, the others the sheets over it, the last on top.

```swift
struct MainWindow: Window {
    @State private var sheets: [String] = []

    var page: any Page {
        ModalStack($sheets) {
            Button("Settings").onClicked { sheets.append("Settings") }
        } destination: { sheet in
            Button("Close \(sheet)").onClicked { sheets.removeLast() }
        }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [BarElement](tiers/BarElement.md)

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

| Host | Created | Members (7) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 4 ✅ | sheet `NSWindow` |  |
| UIKit | ✅ | 4 ✅ · 2 – | `present(_:animated:)` |  |
| Android Views | ✅ | 3 ✅ · 2 – | full-screen `Dialog` (?) |  |
| WinUI 3 | ✅ | 6 ✅ | `ContentDialog` (?) |  |
| GTK 4 | ✅ | 4 ✅ · 2 – | modal `GtkWindow`; libadwaita `AdwDialog` |  |
| Web |  |  | `<dialog>` with `showModal()` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `popped` | event | `Int` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | · | · | · |  |  |  | cannot read accessibilityIdentifier of ModalStack - AppKit's driver has no path for it yet; UIKit: cannot read accessibilityIdentifier of ModalStack - UIKit's driver has no path for it yet; Android Views: cannot read accessibilityIdentifier of ModalStack - Android's driver has no path for it yet; GTK 4: not realized |

## From [BarElement](tiers/BarElement.md)

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `barBackgroundColor` | property | `Color` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `barForegroundColor` | property | `Color` | adaptive | · | ✅ | · | ✅ | ✅ |  | cannot read barForegroundColor of ModalStack - AppKit's driver has no path for it yet; Android Views: cannot read barForegroundColor of ModalStack - Android's driver has no path for it yet |
| `barIcon` | property | `ImageSource` | adaptive | · | – | – | ✅ | – |  | cannot read barIcon of ModalStack - AppKit's driver has no path for it yet; UIKit: A UIKit bar is each page's own: it shows that page's title, and no application's mark.; Android Views: An Android bar is its stack's own: it shows its page's title, and no application's mark.; GTK 4: A GNOME header bar is its page's own and shows no application's mark. |
| `barSubtitle` | property | `String` | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `barTitle` | property | `String` | adaptive | ✅ | – | – | ✅ | – |  | UIKit: A UIKit bar is each page's own and names that page; an application names itself in none.; Android Views: An Android bar is its stack's own and names its page; an application names itself in none.; GTK 4: A GNOME header bar is its page's own and names that page; an application names itself in none. |
