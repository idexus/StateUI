<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive |  |  |  |  |  |  |  |
| `created` | event |  | adaptive |  |  |  |  |  |  |  |
| `deactivated` | event |  | adaptive |  |  |  |  |  |  |  |
| `destroying` | event |  | adaptive |  |  |  |  |  |  |  |
| `floatsOnTop` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `height` | property | `Double` | native |  |  |  |  |  |  |  |
| `hidesWhenInactive` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `isMaximizable` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `isMinimizable` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `isTranslucent` | property | `Bool` | adaptive |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native |  |  |  |  |  |  |  |
| `maximumWidth` | property | `Double` | native |  |  |  |  |  |  |  |
| `minimumHeight` | property | `Double` | native |  |  |  |  |  |  |  |
| `minimumWidth` | property | `Double` | native |  |  |  |  |  |  |  |
| `modalPopped` | event | `Int` | adaptive |  |  |  |  |  |  |  |
| `resumed` | event |  | adaptive |  |  |  |  |  |  |  |
| `stopped` | event |  | adaptive |  |  |  |  |  |  |  |
| `title` | property | `String` | native |  |  |  |  |  |  |  |
| `width` | property | `Double` | native |  |  |  |  |  |  |  |
| `windowType` | property | `WindowType` | structure |  |  |  |  |  |  |  |
| `windowValue` | property | `String` | structure |  |  |  |  |  |  |  |
| `x` | property | `Double` | structure |  |  |  |  |  |  |  |
| `y` | property | `Double` | structure |  |  |  |  |  |  |  |

Realization:

- **AppKit**: `NSWindow`
- **UIKit**: `UIWindow`
- **GTK 4**: `GtkApplicationWindow`
- **Android Views**: `Activity`
- **WinUI 3**: `Window`
- **Web**: browser `window`
