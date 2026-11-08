<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SubmitElement

What a field the user submits holds and reports: the word its key shows, and the submission.

```swift
@State var city = ""

TextField($city)
    .submitLabel(.done)
    .onSubmitted { print("saved") }
```

Worn by: [SearchField](../SearchField.md) · [TextField](../TextField.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/SubmitElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onSubmitted` (`submitted`) | event |  | native |
| `submitLabel` | property | `SubmitLabel` | adaptive |
