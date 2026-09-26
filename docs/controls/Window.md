<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `created` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `deactivated` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `destroying` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `floatsOnTop` | property | `Bool` | adaptive |  |  |  |  | ✅ |  | cannot read floatsOnTop of Window - AppKit's driver has no path for it yet |
| `height` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read height of Window - AppKit's driver has no path for it yet |
| `hidesWhenInactive` | property | `Bool` | adaptive |  |  |  |  | ✅ |  | cannot read isVisible of Window - AppKit's driver has no path for it yet |
| `isMaximizable` | property | `Bool` | adaptive |  |  |  |  | ✅ |  | cannot read isMaximizable of Window - AppKit's driver has no path for it yet |
| `isMinimizable` | property | `Bool` | adaptive |  |  |  |  | ✅ |  | cannot read isMinimizable of Window - AppKit's driver has no path for it yet |
| `isTranslucent` | property | `Bool` | adaptive |  |  |  |  | ✅ |  | cannot read isTranslucent of Window - AppKit's driver has no path for it yet |
| `maximumHeight` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read maximumHeight of Window - AppKit's driver has no path for it yet |
| `maximumWidth` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read maximumWidth of Window - AppKit's driver has no path for it yet |
| `minimumHeight` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read minimumHeight of Window - AppKit's driver has no path for it yet |
| `minimumWidth` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read minimumWidth of Window - AppKit's driver has no path for it yet |
| `modalPopped` | event | `Int` | adaptive | ✅ |  |  |  | ✅ |  | Android Views: cannot goBack on Window - Android's driver has no path for it yet |
| `resumed` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `stopped` | event |  | adaptive | ✅ |  |  | ✅ | ✅ |  |  |
| `title` | property | `String` | native |  |  |  |  | ✅ |  | cannot read title of Window - AppKit's driver has no path for it yet; Android Views: cannot read title of Window - Android's driver has no path for it yet |
| `width` | property | `Double` | native |  |  |  |  | ✅ |  | cannot read width of Window - AppKit's driver has no path for it yet |
| `windowType` | property | `WindowType` | structure | ✅ |  |  |  | ✅ |  |  |
| `windowValue` | property | `String` | structure |  |  |  |  | ✅ |  | cannot read windowValue of Window - AppKit's driver has no path for it yet |
| `x` | property | `Double` | structure |  |  |  |  | ✅ |  | cannot read x of Window - AppKit's driver has no path for it yet |
| `y` | property | `Double` | structure |  |  |  |  | ✅ |  | cannot read y of Window - AppKit's driver has no path for it yet |

Realization:

- **AppKit**: `NSWindow`
- **UIKit**: `UIWindow`
- **GTK 4**: `GtkApplicationWindow`
- **Android Views**: `Activity`
- **WinUI 3**: `Window`
- **Web**: browser `window`
