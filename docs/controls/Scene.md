<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Scene

One session of the application: its main window, the windows it opens beside it, and the state they share.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

| Host | Created | Members | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 6 ✅ of 6 | `NSApplication` / structure |  |
| UIKit | ✅ | 4 ✅ of 6 | `UIApplication` / `UIWindowScene` |  |
| GTK 4 |  |  | `GtkApplication` / structure | no test of it has run yet |
| Android Views | ✅ | 4 ✅ of 6 | `Application` / structure |  |
| WinUI 3 | ✅ | 6 ✅ of 6 | `Application` / structure |  |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ |  | ✅ | ✅ |  |  |
| `deactivated` | event |  | adaptive | ✅ | ✅ |  | ✅ | ✅ |  |  |
| `destroying` | event |  | adaptive | ✅ | ✅ |  | ✅ | ✅ |  |  |
| `stopped` | event |  | adaptive | ✅ | ✅ |  | ✅ | ✅ |  |  |
| `windowClosed` | event | `String` | adaptive | ✅ |  |  |  | ✅ |  |  |
| `windowRestored` | event | `(String, String?)` | adaptive | ✅ |  |  |  | ✅ |  |  |
