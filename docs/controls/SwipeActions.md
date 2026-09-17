<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SwipeActions

One of a swipe view's four collections of actions, and what they do.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/SwipeActionsContract.swift`.

## SwipeActions's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `mode` | property | `SwipeMode` | stateUI | ✅ |  |  |  |  |  |  |  |
| `side` | property | `SwipeSide` | stateUI | ✅ |  |  |  |  |  |  |  |
| `swipeBehaviorOnInvoked` | property | `SwipeBehaviorOnInvoked` | stateUI | ✅ |  |  |  |  |  |  |  |

Realization:

- **MAUI**: `SwipeItems` / `SwipeItem`
- **AppKit**: structure
- **UIKit**: structure
- **GTK 4**: structure
- **Android Views**: structure
- **WinUI 3**: structure
- **Web**: structure
