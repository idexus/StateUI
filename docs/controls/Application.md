<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Application

The application at the root of a StateUI tree, and what its host does for it with no control behind it: questions for the user, the clock and the time zone, the screen reader, what is kept.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSApplication` / structure | no run of it on these sources |
| UIKit |  |  | `UIApplication` / `UIWindowScene` | no run of it on these sources |
| Android Views |  |  | `Application` / structure | no run of it on these sources |
| WinUI 3 | ✅ | 12 ✅ | `Application` / structure |  |
| GTK 4 | ✅ | 3 ✅ | `GtkApplication` / structure |  |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/ApplicationContract.swift`.

## Application's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `alert` | act | `(String, String, String) -> Void` |  |  |  |  | ✅ | · |  | GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `announce` | act | `(String) -> Void` |  |  |  |  | ✅ | · |  | GTK 4: cannot read what the screen reader said - GTK's driver has no path for it yet |
| `chooseAction` | act | `(String, String?, String?, [String]) -> String?` |  |  |  |  | ✅ | · |  | GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `confirm` | act | `(String, String, String, String) -> Bool` |  |  |  |  | ✅ | · |  | GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `currentTime` | act | `() -> [Double]` |  |  |  |  | ✅ | ✅ |  |  |
| `currentTimeZone` | act | `() -> String` |  |  |  |  | ✅ | ✅ |  |  |
| `handlerFailed` | act | `(String) -> Void` |  |  |  |  | ✅ | · |  | GTK 4: cannot read the log - GTK's driver has no path for it yet |
| `hideOnScreenKeyboard` | act | `() -> Bool` |  |  |  |  | ✅ | · |  | GTK 4: cannot focus on TextField - GTK's driver has no path for it yet |
| `persistSceneValue` | act | `(Name, Name, PropValue) -> Void` |  |  |  |  | ✅ |  |  | GTK 4: not realized |
| `persistValue` | act | `(Name, PropValue) -> Void` |  |  |  |  | ✅ | · |  | GTK 4: cannot read what is kept - GTK's driver has no path for it yet |
| `prompt` | act | `(String, String, String, String, String?, Int?, InputPurpose, String) -> String?` |  |  |  |  | ✅ | · |  | GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `utcOffset` | act | `(String?, CalendarDate?) -> Int` |  |  |  |  | ✅ | ✅ |  |  |
