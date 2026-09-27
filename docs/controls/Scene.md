<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Scene

One session of the application: its main window, the windows it opens beside it, and the state they share.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 6 ✅ | `NSApplication` / structure |  |
| UIKit | ✅ | 4 ✅ | `UIApplication` / `UIWindowScene` |  |
| Android Views | ✅ | 4 ✅ | `Application` / structure |  |
| WinUI 3 | ⌛ |  | `Application` / structure | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkApplication` / structure | no run of it on these sources |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `deactivated` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `destroying` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `stopped` | event |  | adaptive | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `windowClosed` | event | `String` | adaptive | ✅ | ⏸ |  | ⌛ |  |  | UIKit: waits on Window.windowType, not realized yet; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `windowRestored` | event | `(String, String?)` | adaptive | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
