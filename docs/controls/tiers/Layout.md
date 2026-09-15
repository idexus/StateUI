<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Layout

What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.

Wears: [View](View.md) · [PaddingElement](PaddingElement.md)

Worn by: [AbsoluteLayout](../AbsoluteLayout.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [VStack](../VStack.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/LayoutContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `avoidsSafeArea` | property | `SafeAreaEdges` | adaptive |
| `clipsContent` | property | `Bool` | native |
| `letsInputThrough` | property | `Bool` | native |
