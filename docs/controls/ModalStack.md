<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ModalStack

The pages presented over a window, the last of them on top.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🔌 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said at another revision of its family than it stands at · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | sheet `NSWindow` | no run of it on these sources |
| UIKit |  |  | `present(_:animated:)` | no run of it on these sources |
| Android Views |  |  | full-screen `Dialog` (?) | no run of it on these sources |
| WinUI 3 | ✅ |  | `ContentDialog` (?) |  |
| GTK 4 |  |  | modal `GtkWindow`; libadwaita `AdwDialog` | not realized |
| Web |  |  | `<dialog>` with `showModal()` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

ModalStack declares no members of its own.
