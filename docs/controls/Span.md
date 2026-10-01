<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Span

One run of text inside a label, with its own colour, size and weight.

```swift
Label()
    .spans {
        TextSpan("Sold out")
            .textColor(.firebrick)
            .background(.yellow)
        TextSpan(" until Monday")
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ |  | `NSTextField` label; `NSAttributedString` runs |  |
| UIKit | ✅ |  | `UILabel`; `NSAttributedString` runs |  |
| Android Views | ✅ |  | `TextView`; `SpannableString` spans |  |
| WinUI 3 | ✅ | 9 ✅ | `TextBlock`; `Run` inlines |  |
| GTK 4 | ✅ | 9 ✅ | `GtkLabel`; `PangoAttrList` runs |  |
| Web |  |  | text element; `<span>` runs | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Text/SpanContract.swift`.

## Span's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `background` | property | `Color` | native |  | · | · | ✅ | ✅ |  | not realized; UIKit: cannot read background of Span - UIKit's driver has no path for it yet; Android Views: cannot read background of Span - Android's driver has no path for it yet |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ◐ | ◐ | ◐ | ✅ | ✅ |  | cannot read text of Span - AppKit's driver has no path for it yet; UIKit: cannot read text of Span - UIKit's driver has no path for it yet; Android Views: cannot read text of Span - Android's driver has no path for it yet |
| `textCase` | property | `TextCase` | native | · | · | · | ✅ | ✅ |  | cannot read text of Span - AppKit's driver has no path for it yet; UIKit: cannot read text of Span - UIKit's driver has no path for it yet; Android Views: cannot read text of Span - Android's driver has no path for it yet |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native |  |  |  | ✅ | ✅ |  | not realized; UIKit: not realized; Android Views: not realized |
| `textColor` | property | `Color` | native |  | · | · | ✅ | ✅ |  | not realized; UIKit: cannot read textColor of Span - UIKit's driver has no path for it yet; Android Views: cannot read textColor of Span - Android's driver has no path for it yet |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | · | · | · | ✅ | ✅ |  | cannot read fontAttributes of Span - AppKit's driver has no path for it yet; UIKit: cannot read fontAttributes of Span - UIKit's driver has no path for it yet; Android Views: cannot read fontAttributes of Span - Android's driver has no path for it yet |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `fontFamily` | property | `Name` | native |  | · |  | ✅ | ✅ |  | not realized; UIKit: cannot read fontFamily of Span - UIKit's driver has no path for it yet; Android Views: not realized |
| `fontSize` | property | `Double` | native |  | · | · | ✅ | ✅ |  | not realized; UIKit: cannot read fontSize of Span - UIKit's driver has no path for it yet; Android Views: cannot read fontSize of Span - Android's driver has no path for it yet |

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineHeight` | property | `Double` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `textDecorations` | property | `TextDecorations` | native |  | · | · | ✅ | ✅ |  | not realized; UIKit: cannot read textDecorations of Span - UIKit's driver has no path for it yet; Android Views: cannot read textDecorations of Span - Android's driver has no path for it yet |
