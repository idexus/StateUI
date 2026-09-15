<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# MenuItemElement

What every item a reader chooses from has - a menu's entry, a toolbar's item, a swipe's action: a caption, a picture, and something to run.

Wears: [PropertyContainer](PropertyContainer.md)

Worn by: [MenuItem](../MenuItem.md) · [SwipeAction](../SwipeAction.md) · [ToolbarItem](../ToolbarItem.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/MenuItemElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onClicked` (`clicked`) | event |  | native |
| `icon` | property | `ImageSource` | adaptive |
| `isDestructive` | property | `Bool` | adaptive |
| `isEnabled` | property | `Bool` | native |
| `text` | property | `String` | native |
