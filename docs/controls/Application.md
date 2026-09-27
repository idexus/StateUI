<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Application

The application at the root of a StateUI tree, and what its host does for it with no control behind it: questions for the user, the clock and the time zone, the screen reader, what is kept.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 12 ✅ | `NSApplication` / structure |  |
| UIKit | ✅ | 11 ✅ | `UIApplication` / `UIWindowScene` |  |
| Android Views | ✅ | 7 ✅ | `Application` / structure |  |
| WinUI 3 | ⌛ |  | `Application` / structure | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkApplication` / structure | no run of it on these sources |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/ApplicationContract.swift`.

## Application's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `alert` | act | `(String, String, String) -> Void` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `announce` | act | `(String) -> Void` |  | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot read what the screen reader said - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `chooseAction` | act | `(String, String?, String?, [String]) -> String?` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `confirm` | act | `(String, String, String, String) -> Bool` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `currentTime` | act | `() -> [Double]` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `currentTimeZone` | act | `() -> String` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `handlerFailed` | act | `(String) -> Void` |  | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot read the log - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `hideOnScreenKeyboard` | act | `() -> Bool` |  | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot focus on TextField - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `persistSceneValue` | act | `(Name, Name, PropValue) -> Void` |  | ✅ |  |  | ⌛ |  |  | UIKit: not realized; Android Views: not realized; WinUI 3: a run of other sources said: ✅ |
| `persistValue` | act | `(Name, PropValue) -> Void` |  | ✅ | ✅ | · | ⌛ |  |  | Android Views: cannot read what is kept - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `prompt` | act | `(String, String, String, String, String?, Int?, InputPurpose, String) -> String?` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
| `utcOffset` | act | `(String?, CalendarDate?) -> Int` |  | ✅ | ✅ | ✅ | ⌛ |  |  | WinUI 3: a run of other sources said: ✅ |
