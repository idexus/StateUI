<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Application

The application at the root of a StateUI tree, and what its host does for it with no control behind it: questions for the user, the clock and the time zone, the screen reader, what is kept.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/ApplicationContract.swift`.

## Application's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `alert` | act | `(String, String, String) -> Void` |  |  |  |  |  | ✅ |  |  |
| `announce` | act | `(String) -> Void` |  |  |  |  |  | ✅ |  |  |
| `chooseAction` | act | `(String, String?, String?, [String]) -> String?` |  |  |  |  |  | ✅ |  |  |
| `confirm` | act | `(String, String, String, String) -> Bool` |  |  |  |  |  | ✅ |  |  |
| `currentTime` | act | `() -> [Double]` |  |  |  |  |  | ✅ |  |  |
| `currentTimeZone` | act | `() -> String` |  |  |  |  |  | ✅ |  |  |
| `handlerFailed` | act | `(String) -> Void` |  |  |  |  |  | ✅ |  |  |
| `hideOnScreenKeyboard` | act | `() -> Bool` |  |  |  |  |  | ✅ |  |  |
| `persistSceneValue` | act | `(Name, Name, PropValue) -> Void` |  |  |  |  |  | ✅ |  |  |
| `persistValue` | act | `(Name, PropValue) -> Void` |  |  |  |  |  | ✅ |  |  |
| `prompt` | act | `(String, String, String, String, String?, Int?, InputPurpose, String) -> String?` |  |  |  |  |  | ✅ |  |  |
| `utcOffset` | act | `(String?, CalendarDate?) -> Int` |  |  |  |  |  | ✅ |  |  |

Realization:

- **AppKit**: `NSApplication` / structure
- **UIKit**: `UIApplication` / `UIWindowScene`
- **GTK 4**: `GtkApplication` / structure
- **Android Views**: `Application` / structure
- **WinUI 3**: `Application` / structure
- **Web**: `document` / structure
