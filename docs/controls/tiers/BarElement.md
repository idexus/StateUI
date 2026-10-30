<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# BarElement

What an arrangement declares of the bar while it stands on the visible path: its look.

```swift
struct MainPage: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            Text("Inbox")
        } destination: { message in
            Text("Message \(message)")
        }
        .barBackground(.cornflowerBlue)
        .barForegroundColor(.white)
    }
}
```

Worn by: [NavigationStack](../NavigationStack.md) · [SplitView](../SplitView.md) · [TabView](../TabView.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/BarElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `barBackground` | property | `Material` | adaptive |
| `barForegroundColor` | property | `Color` | adaptive |
| `barScrollEdge` | property | `ScrollEdge` | adaptive |
| `toolbarStyle` | property | `ToolbarStyle` | adaptive |
| `toolbarSpacing` | property | `Double` | adaptive |
