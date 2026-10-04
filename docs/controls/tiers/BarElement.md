<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# BarElement

What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.

```swift
struct MainPage: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            Text("Inbox")
        } destination: { message in
            Text("Message \(message)")
        }
        .barTitle("Mail")
        .barBackgroundColor(.cornflowerBlue)
        .barForegroundColor(.white)
    }
}
```

Worn by: [ModalStack](../ModalStack.md) · [NavigationStack](../NavigationStack.md) · [SplitView](../SplitView.md) · [TabView](../TabView.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/BarElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `barBackgroundColor` | property | `Color` | adaptive |
| `barForegroundColor` | property | `Color` | adaptive |
| `barIcon` | property | `ImageSource` | adaptive |
| `barSubtitle` | property | `String` | adaptive |
| `barTitle` | property | `String` | adaptive |
