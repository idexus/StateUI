<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Spans

The runs a label is made of, in order.

```swift
Label()
    .spans {
        TextSpan("let ").textColor(.purple)
        TextSpan("count").fontAttributes(.bold)
        TextSpan(" = 0")
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

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

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ |  | `NSTextField` label; `NSAttributedString` runs |  |
| UIKit | ✅ |  | `UILabel`; `NSAttributedString` runs |  |
| Android Views | ✅ |  | `TextView`; `SpannableString` spans |  |
| WinUI 3 | ✅ |  | `TextBlock`; `Run` inlines |  |
| GTK 4 | ✅ |  | `GtkLabel`; `PangoAttrList` runs |  |
| Web |  |  | text element; `<span>` runs | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Text/SpansContract.swift`.

## Spans's own members

Spans declares no members of its own.
