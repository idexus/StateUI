<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (23) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSWindow` |  |
| UIKit | ⌛ |  | `UIWindow` |  |
| Android Views | ⌛ |  | `Activity` |  |
| WinUI 3 | ⌛ |  | `Window` |  |
| GTK 4 |  |  | `GtkApplicationWindow` | no run of it on these sources |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `created` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `deactivated` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `destroying` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `floatsOnTop` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `hidesWhenInactive` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `isMaximizable` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `isMinimizable` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `isTranslucent` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `modalPopped` | event | `Int` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `resumed` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `stopped` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `title` | property | `String` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `width` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `windowType` | property | `WindowType` | structure | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `windowValue` | property | `String` | structure | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `x` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
| `y` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ⌛ |  |  |  |
