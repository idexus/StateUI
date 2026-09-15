# Scene

One session of the application: its main window, the windows it opens beside it, and the state they share.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/Scene.swift` and `lib/StateUI/Sources/Core/Scenes.swift`.

## Scene's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | handler |  | ✅ |  |  |  |  |  |  |
| `deactivated` | handler |  | ✅ |  |  |  |  |  |  |
| `destroying` | handler |  | ✅ |  |  |  |  |  |  |
| `stopped` | handler |  | ✅ |  |  |  |  |  |  |
| `windowClosed` | handler |  | ✅ |  |  |  |  |  |  |
| `windowRestored` | handler |  | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `Application` / structure
- **AppKit**: `NSApplication` / structure
- **UIKit**: `UIApplication` / `UIWindowScene`
- **GTK 4**: `GtkApplication` / structure
- **Android Views**: `Application` / structure
- **WinUI 3**: `Application` / structure
- **Web**: `document` / structure
