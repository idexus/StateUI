<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PageElement

What a page shows about itself - a title and a picture where another container presents it as an item, and what it stands on - and the links its window is given. A page and an arrangement say them under the same keys, so both wear this tier, and it wears nothing: an arrangement's background is the ground of its pages that say none.

```swift
@State var path: [String] = []

NavigationStack($path) {
    Text("General")
} destination: { section in
    Text(section)
}
.title("Settings")
.icon("settings.png")
```

Worn by: [NavigationStack](../NavigationStack.md) · [Page](../Page.md) · [SplitView](../SplitView.md) · [TabView](../TabView.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/PageElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `background` | property | `Material` | adaptive |
| `icon` | property | `ImageSource` | adaptive |
| `onLinkOpened` (`linkOpened`) | event | `String` | adaptive |
| `title` | property | `String` | native |
