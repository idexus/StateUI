<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# TextSpan

One run of text inside a label, with its own colour, size and weight.

```swift
Text()
    .spans {
        TextSpan("Sold out")
            .textColor(.firebrick)
            .background(.yellow)
        TextSpan(" until Monday")
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [TextualElement](tiers/TextualElement.md) · [TextStyleElement](tiers/TextStyleElement.md) · [FontElement](tiers/FontElement.md) · [LineHeightElement](tiers/LineHeightElement.md) · [DecorableTextElement](tiers/DecorableTextElement.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

<table>
<thead><tr><th>Host</th><th>Created</th><th>Members (12)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td></td><td><code>NSTextField</code> label; <code>NSAttributedString</code> runs</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td></td><td><code>UILabel</code>; <code>NSAttributedString</code> runs</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>7 ✅</td><td><code>TextView</code>; <code>SpannableString</code> spans</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>9 ✅</td><td><code>TextBlock</code>; <code>Run</code> inlines</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>9 ✅</td><td><code>GtkLabel</code>; <code>PangoAttrList</code> runs</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>9 ✅</td><td>text element; <code>&lt;span&gt;</code> runs</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Text/TextSpanContract.swift`.

## TextSpan's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized<br>UIKit: cannot read background of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
</table>

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>accessibilityIdentifier</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
</table>

## From [TextualElement](tiers/TextualElement.md)

What every element showing words has: the words, and the case they are drawn in.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>text</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">◐</td><td align="center">◐</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read text of TextSpan - AppKit's driver has no path for it yet<br>UIKit: cannot read text of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>textCase</code></td><td>property</td><td><code>TextCase</code></td><td>native</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read text of TextSpan - AppKit's driver has no path for it yet<br>UIKit: cannot read text of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
</table>

## From [TextStyleElement](tiers/TextStyleElement.md)

How text looks wherever it is drawn: its colour and the space between its letters.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>tracking</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>textColor</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized<br>UIKit: cannot read textColor of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
</table>

## From [FontElement](tiers/FontElement.md)

The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>fontAttributes</code></td><td>property</td><td><code>FontAttributes</code></td><td>native</td><td align="center">·</td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: cannot read fontAttributes of TextSpan - AppKit's driver has no path for it yet<br>UIKit: cannot read fontAttributes of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isFontAutoScalingEnabled</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontFamily</code></td><td>property</td><td><code>Name</code></td><td>native</td><td align="center"></td><td align="center">·</td><td align="center"></td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit, Android Views: not realized<br>UIKit: cannot read fontFamily of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>fontSize</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized<br>UIKit: cannot read fontSize of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
</table>

## From [LineHeightElement](tiers/LineHeightElement.md)

How far apart the lines of text are.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>lineHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr>
<tr><td colspan="9">AppKit, UIKit, Android Views, WinUI 3, GTK 4, Web: not realized</td></tr></tbody>
</table>

## From [DecorableTextElement](tiers/DecorableTextElement.md)

The lines drawn through or under text.

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>textDecorations</code></td><td>property</td><td><code>TextDecorations</code></td><td>native</td><td align="center"></td><td align="center">·</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: not realized<br>UIKit: cannot read textDecorations of TextSpan - UIKit's driver has no path for it yet</td></tr></tbody>
</table>
