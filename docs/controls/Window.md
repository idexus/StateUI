<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (23) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 22 ✅ | `NSWindow` |  |
| UIKit | ✅ | 6 ✅ | `UIWindow` |  |
| Android Views | ✅ | 6 ✅ | `Activity` |  |
| WinUI 3 | ⌛ |  | `Window` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkApplicationWindow` | no run of it on these sources |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `created` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `deactivated` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `destroying` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `floatsOnTop` | property | `Bool` | adaptive | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `height` | property | `Double` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `hidesWhenInactive` | property | `Bool` | adaptive | · |  |  | ⌛ |  |  | cannot read isVisible of Window - AppKit's driver has no path for it yet; UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `isMaximizable` | property | `Bool` | adaptive | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `isMinimizable` | property | `Bool` | adaptive | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `isTranslucent` | property | `Bool` | adaptive | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `maximumHeight` | property | `Double` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `maximumWidth` | property | `Double` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `minimumHeight` | property | `Double` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `minimumWidth` | property | `Double` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `modalPopped` | event | `Int` | adaptive | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot goBack on Window - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `resumed` | event |  | adaptive | ✅ |  | ✅ | ⌛ |  |  | UIKit: not realized; WinUI 3: a run of other sources said: ✅ |
| `stopped` | event |  | adaptive | ✅ | ⏸ | ✅ | ⌛ |  |  | UIKit: waits on Window.resumed, not realized yet; WinUI 3: a run of other sources said: ✅ |
| `title` | property | `String` | native | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot read title of Window - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `width` | property | `Double` | native | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `windowType` | property | `WindowType` | structure | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `windowValue` | property | `String` | structure | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `x` | property | `Double` | structure | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `y` | property | `Double` | structure | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
