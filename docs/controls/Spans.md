<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Spans

The runs a label is made of, in order.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/SpansContract.swift`.

## Spans's own members

Spans declares no members of its own.

Realization:

- **MAUI**: `Label`; `FormattedString` / `Span` runs
- **AppKit**: `NSTextField` label; `NSAttributedString` runs
- **UIKit**: `UILabel`; `NSAttributedString` runs
- **GTK 4**: `GtkLabel`; `PangoAttrList` runs
- **Android Views**: `TextView`; `SpannableString` spans
- **WinUI 3**: `TextBlock`; `Run` inlines
- **Web**: text element; `<span>` runs
