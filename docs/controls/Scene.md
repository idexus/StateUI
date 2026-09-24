<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Scene

One session of the application: its main window, the windows it opens beside it, and the state they share.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `deactivated` | event |  | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `destroying` | event |  | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `stopped` | event |  | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `windowClosed` | event | `String` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `windowRestored` | event | `(String, String?)` | adaptive | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `Application` / structure
- **AppKit**: `NSApplication` / structure
- **UIKit**: `UIApplication` / `UIWindowScene`
- **GTK 4**: `GtkApplication` / structure
- **Android Views**: `Application` / structure
- **WinUI 3**: `Application` / structure
- **Web**: `document` / structure
