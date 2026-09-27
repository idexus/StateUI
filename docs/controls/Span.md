<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Span

One run of text inside a label, with its own colour, size and weight.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [TextElement](tiers/TextElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (12) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | `NSTextField` label; `NSAttributedString` runs | a run of other sources said: ✅ |
| UIKit | ⌛ |  | `UILabel`; `NSAttributedString` runs | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `TextView`; `SpannableString` spans | a run of other sources said: ✅ |
| WinUI 3 | ⌛ |  | `TextBlock`; `Run` inlines | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkLabel`; `PangoAttrList` runs | no run of it on these sources |
| Web |  |  | text element; `<span>` runs | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/SpanContract.swift`.

## Span's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `background` | property | `Color` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read background of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [TextElement](tiers/TextElement.md)

What every element showing words has: the words, and the case they are drawn in.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `text` | property | `String` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: ◐ cannot read text of Span - AppKit's driver has no path for it yet; UIKit: a run of other sources said: ◐ cannot read text of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ◐ cannot read text of Span - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |
| `textCase` | property | `TextCase` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: · cannot read text of Span - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read text of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `characterSpacing` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `textColor` | property | `Color` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read textColor of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `fontAttributes` | property | `FontAttributes` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: · cannot read fontAttributes of Span - AppKit's driver has no path for it yet; UIKit: a run of other sources said: · cannot read fontAttributes of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
| `fontAutoScalingEnabled` | property | `Bool` | adaptive | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `fontFamily` | property | `Name` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read fontFamily of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `fontSize` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read fontSize of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read fontSize of Span - Android's driver has no path for it yet; WinUI 3: a run of other sources said: ✅ |

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `lineHeight` | property | `Double` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `textDecorations` | property | `TextDecorations` | native | ⌛ | ⌛ | ⌛ | ⌛ |  |  | a run of other sources said: not realized; UIKit: a run of other sources said: · cannot read textDecorations of Span - UIKit's driver has no path for it yet; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: ✅ |
