<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Popover

A view the platform shows in a popover by the view it is declared on, while a state says so.

```swift
@State var filtering = false

Button("Filters")
    .onClicked { filtering = true }
    .popover(isShown: $filtering) {
        Text("Unread only").padding(12)
    }
```

Layer: `native`. Every base host presents it with its native toolkit.

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
<thead><tr><th>Host</th><th>Created</th><th>Members (2)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>2 ✓</td><td><code>NSPopover</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>1 ✅ · 1 ✓</td><td><code>UIPopoverPresentationController</code> - a sheet on a phone</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>1 ✅ · 1 ✓</td><td><code>PopupWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>1 ✅ · 1 ✓</td><td><code>Flyout</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>1 ✅ · 1 ✓</td><td><code>GtkPopover</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>2 ✅</td><td><code>&lt;div popover&gt;</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Slots/PopoverContract.swift`.

## Popover's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>isShown</code></td><td>property</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read isShown of Popover: the host's own popover, held unshown where a test shows no window</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isShownChanged</code></td><td>event</td><td><code>Bool</code></td><td>native</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: close on Popover: the host's own close of a popover held unshown, as a test shows no window<br>UIKit: only through the host's own: close on Popover: the popover taken away and its delegate told, no tap beside it<br>Android Views: only through the host's own: close on Popover: the popup window dismissed as a touch beside it dismisses it, no touch sent<br>WinUI 3: only through the host's own: close on Popover: the flyout hidden as a click beside it hides it, no click sent<br>GTK 4: only through the host's own: close on Popover: the popover popped down as a click beside it pops it down, no click sent</td></tr></tbody>
</table>
