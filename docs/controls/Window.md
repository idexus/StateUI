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

| Host | Created | Members (22) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 15 ✅ | `NSWindow` |  |
| UIKit | ✅ | 3 ✅ | `UIWindow` |  |
| Android Views | ✅ | 2 ✅ | `Activity` |  |
| WinUI 3 | ⌛ |  | `Window` |  |
| GTK 4 | ⌛ |  | `GtkApplicationWindow` |  |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ | ⌛ |  |  |
| `created` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ | ⌛ |  |  |
| `deactivated` | event |  | adaptive | 🔌 | 🔌 | 🔌 | ⌛ | ⌛ |  | only through the host's own: switchAway on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: only through the host's own: switchAway on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: switchAway on Window: the host told the activity's phase, no activity moved |
| `destroying` | event |  | adaptive | ✅ | 🔌 | 🔌 | ⌛ | ⌛ |  | UIKit: only through the host's own: close on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: close on Window: the host told the activity's phase, no activity moved |
| `floatsOnTop` | property | `Bool` | adaptive | 🔌 |  |  | ⌛ | ⌛ |  | only through the host's own: bringToFront on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: not realized; Android Views: not realized |
| `height` | property | `Double` | native | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `hidesWhenInactive` | property | `Bool` | adaptive | · |  |  | ⌛ | ⌛ |  | cannot read isVisible of Window - AppKit's driver has no path for it yet; UIKit: not realized; Android Views: not realized |
| `isMaximizable` | property | `Bool` | adaptive | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `isMinimizable` | property | `Bool` | adaptive | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `isTranslucent` | property | `Bool` | adaptive | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `maximumHeight` | property | `Double` | native | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `maximumWidth` | property | `Double` | native | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `minimumHeight` | property | `Double` | native | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `minimumWidth` | property | `Double` | native | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `resumed` | event |  | adaptive | 🔌 | 🔌 | 🔌 | ⌛ | ⌛ |  | only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: minimize on Window: the host told the activity's phase, no activity moved |
| `stopped` | event |  | adaptive | 🔌 | 🔌 | 🔌 | ⌛ | ⌛ |  | only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: minimize on Window: the host told the activity's phase, no activity moved |
| `title` | property | `String` | native | ✅ | ✅ | · | ⌛ | ⌛ |  | Android Views: cannot read title of Window - Android's driver has no path for it yet |
| `width` | property | `Double` | native | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `windowType` | property | `WindowType` | structure | 🔌 |  |  | ⌛ | ⌛ |  | only through the host's own: read windowType of Window: the host's restoration record; UIKit: not realized; Android Views: not realized |
| `windowValue` | property | `String` | structure | 🔌 |  |  | ⌛ | ⌛ |  | only through the host's own: read windowValue of Window: the host's restoration record; UIKit: not realized; Android Views: not realized |
| `x` | property | `Double` | structure | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
| `y` | property | `Double` | structure | ✅ |  |  | ⌛ | ⌛ |  | UIKit: not realized; Android Views: not realized |
