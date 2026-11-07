<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# RangeElement

What a control choosing a number in a range holds and reports: a slider, a stepper.

```swift
@State var volume = 5.0

Slider($volume)
    .minimum(0)
    .maximum(11)
    .onValueChanged { print($0) }
```

Worn by: [Slider](../Slider.md) · [Stepper](../Stepper.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/RangeElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `value` | property | `Double` | native |
| `onValueChanged` (`valueChanged`) | event | `Double` | native |
| `minimum` | property | `Double` | native |
| `maximum` | property | `Double` | native |
