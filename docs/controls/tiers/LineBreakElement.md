<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# LineBreakElement

What happens to words too long for their room: they wrap, or they are cut and say so - a text's, a button's caption.

```swift
Text("Words enough to take several lines of a narrow label")
    .lineBreak(.tailTruncation)
    .width(120)
```

Worn by: [Button](../Button.md) · [Text](../Text.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/LineBreakElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `lineBreak` | property | `LineBreak` | native |
