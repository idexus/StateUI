<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# RefreshElement

An element the user pulls to refresh what it shows - a scroller, a list.

```swift
@State var refreshing = false
@State var rows = ["First"]

ItemsView(rows) { Text($0) }
    .isRefreshing($refreshing)
    .onRefreshRequested {
        rows.insert("Fresh", at: 0)
        refreshing = false
    }
```

Worn by: [ItemsView](../ItemsView.md) · [ScrollView](../ScrollView.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/RefreshElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `isRefreshEnabled` | property | `Bool` | native |
| `isRefreshing` | property | `Bool` | native |
| `onRefreshRequested` (`refreshRequested`) | event |  | native |
