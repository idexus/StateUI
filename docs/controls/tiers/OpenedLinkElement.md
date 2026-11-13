<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# OpenedLinkElement

What hears the links its window is given: a link opened into the application - one chosen elsewhere, its scheme the application's - goes to the window it names, else the one the user came to last, and every page and arrangement there that hears links takes it.

```swift
@State var opened = ""

SplitView {
    Text("Notes")
} detail: {
    Text(opened)
}
.onLinkOpened { address in opened = address }
```

Worn by: [NavigationStack](../NavigationStack.md) · [Page](../Page.md) · [SplitView](../SplitView.md) · [TabView](../TabView.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/OpenedLinkElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `onLinkOpened` (`linkOpened`) | event | `String` | adaptive |
