<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PlaceholderElement

The words an element shows while it holds nothing: a field while it is empty, a picker while nothing is chosen.

```swift
@State var city = ""

TextField($city)
    .placeholder("City")
```

Worn by: [Picker](../Picker.md) · [SearchField](../SearchField.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/PlaceholderElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `placeholder` | property | `String` | native |
