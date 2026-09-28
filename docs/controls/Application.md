<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Application

The application at the root of a StateUI tree, and what its host does for it with no control behind it: questions for the user, the clock and the time zone, the screen reader, what is kept.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSApplication` / structure | a run of other sources said: ✅ |
| UIKit | ⌛ |  | `UIApplication` / `UIWindowScene` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `Application` / structure | a run of other sources said: ✅ |
| WinUI 3 | ✅ | 12 ✅ | `Application` / structure |  |
| GTK 4 |  |  | `GtkApplication` / structure | no run of it on these sources |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/ApplicationContract.swift`.

## Application's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `alert` | act | `(String, String, String) -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: a run of other sources said: 🪞 only through the host's own: read a question: the buttons' captions the host keeps; Android Views: a run of other sources said: 🪞 only through the host's own: read a question: what the relay keeps of the dialog it showed |
| `announce` | act | `(String) -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read what the screen reader said: the host's own list of what it announced; UIKit: a run of other sources said: 🪞 only through the host's own: read what the screen reader said: the host's own list of what it announced; Android Views: a run of other sources said: · cannot read what the screen reader said - Android's driver has no path for it yet |
| `chooseAction` | act | `(String, String?, String?, [String]) -> String?` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: a run of other sources said: 🪞 only through the host's own: read a question: the buttons' captions the host keeps; Android Views: a run of other sources said: 🪞 only through the host's own: read a question: what the relay keeps of the dialog it showed |
| `confirm` | act | `(String, String, String, String) -> Bool` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: a run of other sources said: 🪞 only through the host's own: read a question: the buttons' captions the host keeps; Android Views: a run of other sources said: 🪞 only through the host's own: read a question: what the relay keeps of the dialog it showed |
| `currentTime` | act | `() -> [Double]` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `currentTimeZone` | act | `() -> String` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
| `handlerFailed` | act | `(String) -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read the log - Android's driver has no path for it yet |
| `hideOnScreenKeyboard` | act | `() -> Bool` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot focus on TextField - Android's driver has no path for it yet |
| `persistSceneValue` | act | `(Name, Name, PropValue) -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized |
| `persistValue` | act | `(Name, PropValue) -> Void` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read what is kept - Android's driver has no path for it yet |
| `prompt` | act | `(String, String, String, String, String?, Int?, InputPurpose, String) -> String?` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: 🪞 only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: a run of other sources said: 🪞 only through the host's own: read a question: the buttons' captions the host keeps; Android Views: a run of other sources said: 🪞 only through the host's own: read a question: what the relay keeps of the dialog it showed |
| `utcOffset` | act | `(String?, CalendarDate?) -> Int` |  | ⌛ | ⌛ | ⌛ | ✅ |  |  | a run of other sources said: ✅; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅ |
