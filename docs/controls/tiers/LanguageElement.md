<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# LanguageElement

The language a branch of the interface is written in: the one a screen reader speaks its words in, and whose rules set them - where they break, how they hyphenate. The library says it where a `Localization` is given - the language it speaks - and everything under that element holds it, as the nearest wins.

```swift
enum Language: LocaleTag, CaseIterable {
    case english = "en"
    case polish = "pl"
}

enum Catalog: LocalizationCatalog {
    static let defaultLanguage = Language.english
}

struct LetterPage: View {
    @State private var localization = Localization(Catalog.self, language: .polish)

    var body: some View {
        Text("Dzień dobry")
            .environment(localization)
    }
}
```

Worn by: [Button](../Button.md) · [Canvas](../Canvas.md) · [Capsule](../Capsule.md) · [CheckBox](../CheckBox.md) · [ColorPicker](../ColorPicker.md) · [DatePicker](../DatePicker.md) · [Ellipse](../Ellipse.md) · [Fill](../Fill.md) · [Grid](../Grid.md) · [HStack](../HStack.md) · [Image](../Image.md) · [ItemsView](../ItemsView.md) · [Line](../Line.md) · [Link](../Link.md) · [Map](../Map.md) · [MotionLayout](../MotionLayout.md) · [Path](../Path.md) · [Picker](../Picker.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [ProgressBar](../ProgressBar.md) · [Rectangle](../Rectangle.md) · [ScrollView](../ScrollView.md) · [SearchField](../SearchField.md) · [Separator](../Separator.md) · [Slider](../Slider.md) · [Space](../Space.md) · [Spinner](../Spinner.md) · [Stepper](../Stepper.md) · [Switch](../Switch.md) · [Text](../Text.md) · [TextEditor](../TextEditor.md) · [TextField](../TextField.md) · [TimePicker](../TimePicker.md) · [VStack](../VStack.md) · [WebView](../WebView.md) · [Window](../Window.md) · [ZStack](../ZStack.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/LanguageElementContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `language` | property | `LocaleTag` | adaptive |
