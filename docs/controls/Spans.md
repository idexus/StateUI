<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Spans

The runs a label is made of, in order.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `NSTextField` label; `NSAttributedString` runs | no run of it on these sources |
| UIKit |  |  | `UILabel`; `NSAttributedString` runs | no run of it on these sources |
| Android Views |  |  | `TextView`; `SpannableString` spans | no run of it on these sources |
| WinUI 3 | ✅ |  | `TextBlock`; `Run` inlines |  |
| GTK 4 |  |  | `GtkLabel`; `PangoAttrList` runs | no run of it on these sources |
| Web |  |  | text element; `<span>` runs | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Text/SpansContract.swift`.

## Spans's own members

Spans declares no members of its own.
