<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Layout

What every layout has: the edges it runs under what stands over its page on, and whether its children are clipped or let input through.

```swift
VStack {
    Text("Edge to edge")
}
.background(.steelBlue)
.ignoresSafeArea(.all)
.clipsContent(true)
```

Wears: [View](View.md) · [PaddingElement](PaddingElement.md) · [BorderElement](BorderElement.md) · [KeyboardElement](KeyboardElement.md)

Worn by: [Grid](../Grid.md) · [HStack](../HStack.md) · [MotionLayout](../MotionLayout.md) · [VStack](../VStack.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Tiers/LayoutContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `ignoresSafeArea` | property | `SafeAreaEdges` | adaptive |
| `clipsContent` | property | `Bool` | native |
| `letsInputThrough` | property | `Bool` | native |
