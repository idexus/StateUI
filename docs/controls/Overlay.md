<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Overlay

A view shown above a window's page, over everything else it holds.

```swift
@State var offline = true

Switch($offline)
    .overlays {
        if offline {
            Label("Working offline")
                .horizontalAlignment(.center)
                .verticalAlignment(.start)
        }
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

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

| Host | Created | Members (0) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ |  | pass-through `NSView` above the page |  |
| UIKit | ✅ |  | pass-through `UIView` above the page |  |
| Android Views | ◐ |  | top child of a `FrameLayout` | cannot read what reaches Label - Android's driver has no path for it yet |
| WinUI 3 | ✅ |  | top layer of a root `Grid` |  |
| GTK 4 | ⌛ |  | `GtkOverlay` |  |
| Web |  |  | positioned element above the page | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Slots/OverlayContract.swift`.

## Overlay's own members

Overlay declares no members of its own.
