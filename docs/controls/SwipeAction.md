<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SwipeAction

One thing a swipe reveals.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [MenuItemElement](tiers/MenuItemElement.md)

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/SwipeActionContract.swift`.

## SwipeAction's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `background` | property | `Color` | native | ✅ |  |  |  |  |  |  |  |
| `isVisible` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |

Realization:

- **MAUI**: `SwipeItems` / `SwipeItem`
- **AppKit**: structure
- **UIKit**: structure
- **GTK 4**: structure
- **Android Views**: structure
- **WinUI 3**: structure
- **Web**: structure

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ✅ |  |  |  |  |  |  |  |

## From [MenuItemElement](tiers/MenuItemElement.md)

What every item a reader chooses from has - a menu's entry, a toolbar's item, a swipe's action: a caption, a picture, and something to run.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `onClicked` (`clicked`) | event |  | native | ✅ |  |  |  |  |  |  |  |
| `icon` | property | `ImageSource` | adaptive | ✅ |  |  |  |  |  |  |  |
| `isDestructive` | property | `Bool` | adaptive | ✅ |  |  |  |  |  |  |  |
| `isEnabled` | property | `Bool` | native | ✅ |  |  |  |  |  |  |  |
| `text` | property | `String` | native | ✅ |  |  |  |  |  |  |  |
