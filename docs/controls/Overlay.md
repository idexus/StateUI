<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Overlay

A view shown above a window's page, over everything else it holds.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ⌛ |  | pass-through `NSView` above the page | a run of other sources said: ✅ |
| UIKit | ⌛ |  | pass-through `UIView` above the page | a run of other sources said: ✅ |
| Android Views | · |  | top child of a `FrameLayout` | cannot read what reaches Label - Android's driver has no path for it yet |
| WinUI 3 | ⌛ |  | top layer of a root `Grid` | a run of other sources said: ✅ |
| GTK 4 |  |  | `GtkOverlay` | no run of it on these sources |
| Web |  |  | positioned element above the page | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Slots/OverlayContract.swift`.

## Overlay's own members

Overlay declares no members of its own.
