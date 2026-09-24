<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# BorderElement

What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.

Wears: [PropertyContainer](PropertyContainer.md)

Worn by: [Button](../Button.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [RadioButton](../RadioButton.md) · [VStack](../VStack.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Sources/Contracts/Mixins/BorderElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `borderColor` | property | `Color` | native |
| `borderWidth` | property | `Double` | native |
| `cornerRadius` | property | `Int` | native |
| `shape` | property | `ContainerShape` | stateUI |
| `stroke` | property | `Brush` | stateUI |
| `strokeWidth` | property | `Double` | stateUI |
