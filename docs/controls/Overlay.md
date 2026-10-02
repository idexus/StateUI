<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

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
<tr><th>Host</th><th>Created</th><th>Members (0)</th><th>Realization</th></tr>
<tr><td>AppKit</td><td align="center">✅</td><td></td><td>pass-through <code>NSView</code> above the page</td></tr>
<tr><td>UIKit</td><td align="center">✅</td><td></td><td>pass-through <code>UIView</code> above the page</td></tr>
<tr><td rowspan="2">Android Views</td><td align="center">◐</td><td></td><td>top child of a <code>FrameLayout</code></td></tr>
<tr><td colspan="3">cannot read what reaches Label - Android's driver has no path for it yet</td></tr>
<tr><td>WinUI 3</td><td align="center">✅</td><td></td><td>top layer of a root <code>Grid</code></td></tr>
<tr><td>GTK 4</td><td align="center">✅</td><td></td><td><code>GtkOverlay</code></td></tr>
<tr><td rowspan="2">Web</td><td align="center"></td><td></td><td>positioned element above the page</td></tr>
<tr><td colspan="3">no host yet</td></tr>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Slots/OverlayContract.swift`.

## Overlay's own members

Overlay declares no members of its own.
