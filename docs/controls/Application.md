<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Application

The application at the root of a StateUI tree, and what its host does for it with no control behind it: questions for the user, the clock and the time zone, the screen reader, what is kept.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 7 ✅ | `NSApplication` / structure |  |
| UIKit | ✅ | 6 ✅ | `UIApplication` / `UIWindowScene` |  |
| Android Views | ✅ | 4 ✅ | `Application` / structure |  |
| WinUI 3 | ✅ | 12 ✅ | `Application` / structure |  |
| GTK 4 | ✅ | 3 ✅ | `GtkApplication` / structure |  |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/ApplicationContract.swift`.

## Application's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `alert` | act | `(String, String, String) -> Void` |  | 🔌 | 🔌 | 🔌 | ✅ | · |  | only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: only through the host's own: read a question: the buttons' captions the host keeps; Android Views: only through the host's own: read a question: what the relay keeps of the dialog it showed; GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `announce` | act | `(String) -> Void` |  | 🔌 | 🔌 | · | ✅ | · |  | only through the host's own: read what the screen reader said: the host's own list of what it announced; UIKit: only through the host's own: read what the screen reader said: the host's own list of what it announced; Android Views: cannot read what the screen reader said - Android's driver has no path for it yet; GTK 4: cannot read what the screen reader said - GTK's driver has no path for it yet |
| `chooseAction` | act | `(String, String?, String?, [String]) -> String?` |  | 🔌 | 🔌 | 🔌 | ✅ | · |  | only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: only through the host's own: read a question: the buttons' captions the host keeps; Android Views: only through the host's own: read a question: what the relay keeps of the dialog it showed; GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `confirm` | act | `(String, String, String, String) -> Bool` |  | 🔌 | 🔌 | 🔌 | ✅ | · |  | only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: only through the host's own: read a question: the buttons' captions the host keeps; Android Views: only through the host's own: read a question: what the relay keeps of the dialog it showed; GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `currentTime` | act | `() -> [Double]` |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `currentTimeZone` | act | `() -> String` |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `handlerFailed` | act | `(String) -> Void` |  | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot read the log - GTK's driver has no path for it yet |
| `hideOnScreenKeyboard` | act | `() -> Bool` |  | ✅ | ✅ | · | ✅ | · |  | Android Views: cannot focus on TextField - Android's driver has no path for it yet; GTK 4: cannot focus on TextField - GTK's driver has no path for it yet |
| `persistSceneValue` | act | `(Name, Name, PropValue) -> Void` |  | ✅ |  |  | ✅ |  |  | UIKit: not realized; Android Views: not realized; GTK 4: not realized |
| `persistValue` | act | `(Name, PropValue) -> Void` |  | ✅ | ✅ | · | ✅ | · |  | Android Views: cannot read what is kept - Android's driver has no path for it yet; GTK 4: cannot read what is kept - GTK's driver has no path for it yet |
| `prompt` | act | `(String, String, String, String, String?, Int?, InputPurpose, String) -> String?` |  | 🔌 | 🔌 | 🔌 | ✅ | · |  | only through the host's own: read a question: the captions the host keeps, not the alert's buttons; UIKit: only through the host's own: read a question: the buttons' captions the host keeps; Android Views: only through the host's own: read a question: what the relay keeps of the dialog it showed; GTK 4: cannot read a question - GTK's driver has no path for it yet |
| `utcOffset` | act | `(String?, CalendarDate?) -> Int` |  | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
