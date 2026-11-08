<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# SessionElement

What a scene and a window report of the user's attention: coming to the front, leaving it, going out of sight.

```swift
struct StatusPage: View {
    @Environment(\.window) private var window

    var body: some View {
        Text(window.phase == .active ? "In front" : "Behind")
    }
}
```

Worn by: [Scene](../Scene.md) · [Window](../Window.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/SessionElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `activated` | event |  | adaptive |
| `deactivated` | event |  | adaptive |
| `stopped` | event |  | adaptive |
