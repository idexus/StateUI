<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

```swift
struct NotesApp: Application {
    var body: some Scene { WindowGroup { MainPage() } }
}

struct MainPage: View {
    @Environment(\.window) private var window

    var body: some View {
        Text("Hello")
            .onCreated {
                window.title = "Notes"
                window.minimumWidth = 480
            }
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
<thead><tr><th>Host</th><th>Created</th><th>Members (23)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>16 ✅ · 6 ✓</td><td><code>NSWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">⌛</td><td></td><td><code>UIWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">⌛</td><td></td><td><code>Activity</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">⌛</td><td></td><td><code>Window</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">⌛</td><td></td><td><code>GtkApplicationWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">⌛</td><td></td><td>browser <code>window</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>activated</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>background</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td><td align="center"></td></tr></tbody>
<tbody><tr></tr><tr><td><code>created</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>deactivated</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: switchAway on Window: the notification AppKit would post, posted by the driver; the window does not move</td></tr></tbody>
<tbody><tr></tr><tr><td><code>destroying</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>floatsOnTop</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: bringToFront on Window: the notification AppKit would post, posted by the driver; the window does not move</td></tr></tbody>
<tbody><tr></tr><tr><td><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>hidesWhenInactive</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">·</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: cannot read isVisible of Window - AppKit's driver has no path for it yet</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isMaximizable</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isMinimizable</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>isTranslucent</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>resumed</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>stopped</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move</td></tr></tbody>
<tbody><tr></tr><tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>windowType</code></td><td>property</td><td><code>WindowType</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read windowType of Window: the host's restoration record</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>windowValue</code></td><td>property</td><td><code>String</code></td><td>structure</td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read windowValue of Window: the host's restoration record</td></tr></tbody>
<tbody><tr></tr><tr><td><code>x</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>y</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>
