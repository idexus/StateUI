<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PresentedElement

What a page shown over the one beneath it holds and reports: a sheet, a popover.

```swift
@State var editing = false

Button("Edit")
    .onClicked { editing = true }
    .sheet(isPresented: $editing) {
        Text("Editing").padding(16)
    }
```

Worn by: [Popover](../Popover.md) · [Sheet](../Sheet.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/PresentedElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `isPresented` | property | `Bool` | adaptive |
| `isPresentedChanged` | event | `Bool` | adaptive |
