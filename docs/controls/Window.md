<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 22 ✅ of 23 | `NSWindow` |  |
| UIKit | ✅ | 6 ✅ of 23 | `UIWindow` |  |
| Android Views | ✅ | 6 ✅ of 23 | `Activity` |  |
| WinUI 3 | ✅ | 23 ✅ of 23 | `Window` |  |
| GTK 4 |  |  | `GtkApplicationWindow` | no test of it has run yet |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ |  |  |  |
| `created` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ |  |  |  |
| `deactivated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ |  |  |  |
| `destroying` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ |  |  |  |
| `floatsOnTop` | property | `Bool` | adaptive | ✅ |  |  | ✅ |  |  |  |
| `height` | property | `Double` | native | ✅ |  |  | ✅ |  |  |  |
| `hidesWhenInactive` | property | `Bool` | adaptive |  |  |  | ✅ |  |  | cannot read isVisible of Window - AppKit's driver has no path for it yet |
| `isMaximizable` | property | `Bool` | adaptive | ✅ |  |  | ✅ |  |  |  |
| `isMinimizable` | property | `Bool` | adaptive | ✅ |  |  | ✅ |  |  |  |
| `isTranslucent` | property | `Bool` | adaptive | ✅ |  |  | ✅ |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ |  |  | ✅ |  |  |  |
| `maximumWidth` | property | `Double` | native | ✅ |  |  | ✅ |  |  |  |
| `minimumHeight` | property | `Double` | native | ✅ |  |  | ✅ |  |  |  |
| `minimumWidth` | property | `Double` | native | ✅ |  |  | ✅ |  |  |  |
| `modalPopped` | event | `Int` | adaptive | ✅ | ✅ |  | ✅ |  |  | Android Views: cannot goBack on Window - Android's driver has no path for it yet |
| `resumed` | event |  | adaptive | ✅ |  | ✅ | ✅ |  |  |  |
| `stopped` | event |  | adaptive | ✅ |  | ✅ | ✅ |  |  | UIKit: its test waits on Window.resumed, not realized yet |
| `title` | property | `String` | native | ✅ | ✅ |  | ✅ |  |  | Android Views: cannot read title of Window - Android's driver has no path for it yet |
| `width` | property | `Double` | native | ✅ |  |  | ✅ |  |  |  |
| `windowType` | property | `WindowType` | structure | ✅ |  |  | ✅ |  |  |  |
| `windowValue` | property | `String` | structure | ✅ |  |  | ✅ |  |  |  |
| `x` | property | `Double` | structure | ✅ |  |  | ✅ |  |  |  |
| `y` | property | `Double` | structure | ✅ |  |  | ✅ |  |  |  |
