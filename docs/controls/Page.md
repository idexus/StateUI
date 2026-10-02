<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Page

What a container shows as a screen: a window's page, a stack's root and destinations, a tab, either half of a split view, a sheet.

```swift
struct NotePage: ContentView {
    @Environment private var page: PageSession

    var content: some View {
        Label("Nothing written yet.")
            .onCreated {
                page.title = "Note"
                page.hasBackButton = true
            }
    }
}
```

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

Inherits: [PageElement](tiers/PageElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 8 ✅ | custom `NSView` |  |
| UIKit | ✅ | 12 ✅ | `UIViewController` |  |
| Android Views | ✅ | 7 ✅ · 1 – | custom `ViewGroup` |  |
| WinUI 3 | ✅ | 10 ✅ | `Page` |  |
| GTK 4 | ✅ | 8 ✅ · 1 – | custom `GtkWidget` |  |
| Web |  |  | `<section>` | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/PageContract.swift`.

## Page's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `appearing` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `backButtonTitle` | property | `String` | adaptive | · | ✅ | – |  |  |  | cannot read backButtonTitle of Page - AppKit's driver has no path for it yet; Android Views: Android's way back in the bar is an arrow, with no words.; WinUI 3: not realized; GTK 4: not realized |
| `background` | property | `Color` | native | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read background of Page - StateUI draws a page's box on GTK's snapshot, which holds none of its background; its drawing proves it |
| `disappearing` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `hasBackButton` | property | `Bool` | adaptive | ✅ | ✅ | · |  |  |  | Android Views: cannot read hasBackButton of Page - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `hasNavigationBar` | property | `Bool` | adaptive | · | ✅ | · | ✅ | ✅ |  | cannot read hasNavigationBar of Page - AppKit's driver has no path for it yet; Android Views: cannot read hasNavigationBar of Page - Android's driver has no path for it yet |
| `navigatedFrom` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `navigatedTo` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `navigatingFrom` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `padding` | property | `Insets` | native | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |

## From [PageElement](tiers/PageElement.md)

What a page shows about itself where another container presents it as an item - a title and a picture.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `icon` | property | `ImageSource` | adaptive | · | ✅ | · | ✅ | – |  | cannot read icon of Page - AppKit's driver has no path for it yet; Android Views: cannot read icon of Page - Android's driver has no path for it yet; GTK 4: GTK's tab switcher shows a tab's picture in place of its caption, not beside it: the tabs show their captions. |
| `title` | property | `String` | native | ◐ | ✅ | · | ✅ | ✅ |  | cannot read title of Page - AppKit's driver has no path for it yet; Android Views: cannot read title of Page - Android's driver has no path for it yet |
