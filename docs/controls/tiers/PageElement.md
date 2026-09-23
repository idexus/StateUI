<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PageElement

What a page shows about itself where another container presents it as an item - a title and a picture. A page and an arrangement say them under the same keys, so both wear this tier, and it wears nothing: a page carries its title and its icon, and no other value an element carries.

Worn by: [NavigationStack](../NavigationStack.md) · [Page](../Page.md) · [SplitView](../SplitView.md) · [TabbedView](../TabbedView.md)

Declared in `lib/StateUI/Sources/Contracts/Mixins/PageElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `icon` | property | `ImageSource` | adaptive |
| `title` | property | `String` | native |
