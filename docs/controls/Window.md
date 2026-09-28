<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

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

| Host | Created | Members (23) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSWindow` | no run of it on these sources |
| UIKit |  |  | `UIWindow` | no run of it on these sources |
| Android Views |  |  | `Activity` | no run of it on these sources |
| WinUI 3 | ✅ | 23 ✅ | `Window` |  |
| GTK 4 | ⏸ |  | `GtkApplicationWindow` | waits on Window.created, not realized yet |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `created` | event |  | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `deactivated` | event |  | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `destroying` | event |  | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `floatsOnTop` | property | `Bool` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `height` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `hidesWhenInactive` | property | `Bool` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isMaximizable` | property | `Bool` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isMinimizable` | property | `Bool` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `isTranslucent` | property | `Bool` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `modalPopped` | event | `Int` | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `resumed` | event |  | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `stopped` | event |  | adaptive |  |  |  | ✅ |  |  | GTK 4: not realized |
| `title` | property | `String` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `width` | property | `Double` | native |  |  |  | ✅ |  |  | GTK 4: not realized |
| `windowType` | property | `WindowType` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `windowValue` | property | `String` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `x` | property | `Double` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
| `y` | property | `Double` | structure |  |  |  | ✅ |  |  | GTK 4: not realized |
