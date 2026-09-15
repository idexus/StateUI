# Page

What a container shows as a screen: a window's `page`, a navigation stack's root and destinations, a tab, either half of a split view, a sheet.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Views/Application.swift` and `lib/StateUI/Sources/Types/PageSession.swift`.

## Page's own members

| Member | Kind | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `appearing` | handler |  | ✅ |  |  |  |  |  |  |
| `backButtonTitle` | property |  | ✅ |  |  |  |  |  |  |
| `background` | property |  | ✅ |  |  |  |  |  |  |
| `disappearing` | handler |  | ✅ |  |  |  |  |  |  |
| `hasBackButton` | property |  | ✅ |  |  |  |  |  |  |
| `hasNavigationBar` | property |  | ✅ |  |  |  |  |  |  |
| `icon` | property |  | ✅ |  |  |  |  |  |  |
| `navigatedFrom` | handler |  | ✅ |  |  |  |  |  |  |
| `navigatedTo` | handler |  | ✅ |  |  |  |  |  |  |
| `navigatingFrom` | handler |  | ✅ |  |  |  |  |  |  |
| `padding` | property |  | ✅ |  |  |  |  |  |  |
| `title` | property |  | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `ContentPage`
- **AppKit**: custom `NSView`
- **UIKit**: `UIViewController`
- **GTK 4**: custom `GtkWidget`
- **Android Views**: custom `ViewGroup`
- **WinUI 3**: `Page`
- **Web**: `<section>`
