<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Span

One run of text inside a label, with its own colour, size and weight.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md)

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/SpanContract.swift`.

## Span's own members

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `background` | property | `Color` | native | ✅ |  |  |  |  |  |  |  |

Realization:

- **MAUI**: `Label`; `FormattedString` / `Span` runs
- **AppKit**: `NSTextField` label; `NSAttributedString` runs
- **UIKit**: `UILabel`; `NSAttributedString` runs
- **GTK 4**: `GtkLabel`; `PangoAttrList` runs
- **Android Views**: `TextView`; `SpannableString` spans
- **WinUI 3**: `TextBlock`; `Run` inlines
- **Web**: text element; `<span>` runs

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  |  |  |  |  |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ✅ | ✅ |  |  |  |  |  |  |
| `textCase` | property | `TextCase` | native | ✅ | ✅ |  |  |  |  |  |  |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native | ✅ |  |  |  |  |  |  |  |
| `textColor` | property | `Color` | native | ✅ |  |  |  |  |  |  |  |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the reader's text-size setting.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ✅ | ✅ |  |  |  |  |  |  |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive | ✅ |  |  |  |  |  |  |  |
| `fontFamily` | property | `Name` | native | ✅ |  |  |  |  |  |  |  |
| `fontSize` | property | `Double` | native | ✅ |  |  |  |  |  |  |  |

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineHeight` | property | `Double` | native | ✅ |  |  |  |  |  |  |  |

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

| Member | Kind | Value | Layer | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `textDecorations` | property | `TextDecorations` | native | ✅ |  |  |  |  |  |  |  |
