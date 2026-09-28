<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Scene

One session of the application: its main window, the windows it opens beside it, and the state they share.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSApplication` / structure | no run of it on these sources |
| UIKit |  |  | `UIApplication` / `UIWindowScene` | no run of it on these sources |
| Android Views |  |  | `Application` / structure | no run of it on these sources |
| WinUI 3 | ✅ | 6 ✅ | `Application` / structure |  |
| GTK 4 |  |  | `GtkApplication` / structure | no run of it on these sources |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive |  |  |  | ✅ |  |  |  |
| `deactivated` | event |  | adaptive |  |  |  | ✅ |  |  |  |
| `destroying` | event |  | adaptive |  |  |  | ✅ |  |  |  |
| `stopped` | event |  | adaptive |  |  |  | ✅ |  |  |  |
| `windowClosed` | event | `String` | adaptive |  |  |  | ✅ |  |  |  |
| `windowRestored` | event | `(String, String?)` | adaptive |  |  |  | ✅ |  |  |  |
