# Window

A window onto a page.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/Application.swift`, `lib/StateUI/Sources/Types/HostEnvironment.swift` and `lib/StateUI/Sources/Core/Scenes.swift`.

## Window's own members

| Member | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | handler | ✅ |  |  |  |  |  |  |
| `created` | handler | ✅ |  |  |  |  |  |  |
| `deactivated` | handler | ✅ |  |  |  |  |  |  |
| `destroying` | handler | ✅ |  |  |  |  |  |  |
| `floatsOnTop` | property | ✅ |  |  |  |  |  |  |
| `height` | property | ✅ |  |  |  |  |  |  |
| `hidesWhenInactive` | property | ✅ |  |  |  |  |  |  |
| `isMaximizable` | property | ✅ |  |  |  |  |  |  |
| `isMinimizable` | property | ✅ |  |  |  |  |  |  |
| `maximumHeight` | property | ✅ |  |  |  |  |  |  |
| `maximumWidth` | property | ✅ |  |  |  |  |  |  |
| `minimumHeight` | property | ✅ |  |  |  |  |  |  |
| `minimumWidth` | property | ✅ |  |  |  |  |  |  |
| `modalPopped` | handler | ✅ |  |  |  |  |  |  |
| `resumed` | handler | ✅ |  |  |  |  |  |  |
| `stopped` | handler | ✅ |  |  |  |  |  |  |
| `title` | property | ✅ |  |  |  |  |  |  |
| `width` | property | ✅ |  |  |  |  |  |  |
| `windowType` | property | ✅ |  |  |  |  |  |  |
| `windowValue` | property | ✅ |  |  |  |  |  |  |
| `x` | property | ✅ |  |  |  |  |  |  |
| `y` | property | ✅ |  |  |  |  |  |  |

Realization:

- **AppKit**: `NSWindow`
- **UIKit**: `UIWindow`
- **GTK 4**: `GtkApplicationWindow`
- **Android Views**: `Activity`
- **WinUI 3**: `Window`
- **Web**: browser `window`
