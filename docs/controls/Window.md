<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `created` | event |  | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `deactivated` | event |  | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `destroying` | event |  | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `floatsOnTop` | property | `Bool` | adaptive | ☑️ | ✅ |  |  |  |  |  | MAUI: Only Mac Catalyst keeps the window on top; Windows and Linux leave it among the others. |
| `height` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `hidesWhenInactive` | property | `Bool` | adaptive |  | ✅ |  |  |  |  |  |  |
| `isMaximizable` | property | `Bool` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `isMinimizable` | property | `Bool` | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `isTranslucent` | property | `Bool` | adaptive |  | ✅ |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `maximumWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `minimumHeight` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `minimumWidth` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `modalPopped` | event | `Int` | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `resumed` | event |  | adaptive | ✅ | ✅ |  |  |  |  |  |  |
| `stopped` | event |  | adaptive | ✅ | ✅ |  |  | ✅ |  |  |  |
| `title` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `width` | property | `Double` | native | ✅ | ✅ |  |  |  |  |  |  |
| `windowType` | property | `WindowType` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `windowValue` | property | `String` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `x` | property | `Double` | structure | ✅ | ✅ |  |  |  |  |  |  |
| `y` | property | `Double` | structure | ✅ | ✅ |  |  |  |  |  |  |

Realization:

- **MAUI**: `Window`
- **AppKit**: `NSWindow`
- **UIKit**: `UIWindow`
- **GTK 4**: `GtkApplicationWindow`
- **Android Views**: `Activity`
- **WinUI 3**: `Window`
- **Web**: browser `window`
