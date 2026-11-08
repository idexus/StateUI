<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PopupElement

What a control whose choices open in a list of their own holds and reports: a picker, a date's and a time's.

```swift
@State var due = CalendarDate(year: 2026, month: 11, day: 7)
@State var choosing = false

DatePicker($due)
    .isOpen($choosing)
    .onClosed { print("chosen") }
```

Worn by: [DatePicker](../DatePicker.md) · [Picker](../Picker.md) · [TimePicker](../TimePicker.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/PopupElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `isOpen` | property | `Bool` | native |
| `onOpened` (`opened`) | event |  | native |
| `onClosed` (`closed`) | event |  | native |
