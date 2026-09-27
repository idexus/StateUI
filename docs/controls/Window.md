<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (23) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 15 ✅ | `NSWindow` |  |
| UIKit | ⌛ |  | `UIWindow` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `Activity` | a run of other sources said: ✅ |
| WinUI 3 | ⌛ |  | `Window` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkApplicationWindow` | no run of it on these sources |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `created` | event |  | adaptive | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: ✅ |
| `deactivated` | event |  | adaptive | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: switchAway on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: 🪞 only through the host's own: switchAway on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: switchAway on Window: the host told the activity's phase, no activity moved; WinUI 3: a run of other sources said: ✅ |
| `destroying` | event |  | adaptive | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: 🪞 only through the host's own: close on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: close on Window: the host told the activity's phase, no activity moved; WinUI 3: a run of other sources said: ✅ |
| `floatsOnTop` | property | `Bool` | adaptive | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: bringToFront on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `hidesWhenInactive` | property | `Bool` | adaptive | · | ⌛ | ⌛ | ⌛ |  |  | cannot read isVisible of Window - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `isMaximizable` | property | `Bool` | adaptive | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `isMinimizable` | property | `Bool` | adaptive | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `isTranslucent` | property | `Bool` | adaptive | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `maximumHeight` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `modalPopped` | event | `Int` | adaptive | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: goBack on Window: the host's toolbar or sheet entry called, no toolbar item or sheet touched; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot goBack on Window - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `resumed` | event |  | adaptive | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the activity's phase, no activity moved; WinUI 3: a run of other sources said: ✅ |
| `stopped` | event |  | adaptive | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the activity's phase, no activity moved; WinUI 3: a run of other sources said: ✅ |
| `title` | property | `String` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read title of Window - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `width` | property | `Double` | native | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `windowType` | property | `WindowType` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read windowType of Window: the host's restoration record; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `windowValue` | property | `String` | structure | 🪞 | ⌛ | ⌛ | ⌛ |  |  | only through the host's own: read windowValue of Window: the host's restoration record; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `x` | property | `Double` | structure | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `y` | property | `Double` | structure | ✅ | ⌛ | ⌛ | ⌛ |  |  | UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
