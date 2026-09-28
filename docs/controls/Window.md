<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (23) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSWindow` | a run of other sources said: ✅ |
| UIKit | ⌛ |  | `UIWindow` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `Activity` | a run of other sources said: ✅ |
| WinUI 3 | ✅ | 23 ✅ | `Window` |  |
| GTK 4 |  |  | `GtkApplicationWindow` | no run of it on these sources |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `created` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `deactivated` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: switchAway on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: 🪞 only through the host's own: switchAway on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: switchAway on Window: the host told the activity's phase, no activity moved |
| `destroying` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: 🪞 only through the host's own: close on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: close on Window: the host told the activity's phase, no activity moved |
| `floatsOnTop` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: bringToFront on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `height` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `hidesWhenInactive` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: · cannot read isVisible of Window - AppKit's driver has no path for it yet; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `isMaximizable` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `isMinimizable` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `isTranslucent` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `maximumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `minimumHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `minimumWidth` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `modalPopped` | event | `Int` | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: goBack on Window: the host's toolbar or sheet entry called, no toolbar item or sheet touched; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot goBack on Window - Android's driver has no path for it yet |
| `resumed` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the activity's phase, no activity moved |
| `stopped` | event |  | adaptive | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: a run of other sources said: 🪞 only through the host's own: minimize on Window: the host told the activity's phase, no activity moved |
| `title` | property | `String` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read title of Window - Android's driver has no path for it yet |
| `width` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `windowType` | property | `WindowType` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read windowType of Window: the host's restoration record; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `windowValue` | property | `String` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read windowValue of Window: the host's restoration record; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `x` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `y` | property | `Double` | structure | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
