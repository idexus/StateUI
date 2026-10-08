<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Scene

One of the application's scenes, standing while a window of it is open: its windows, and the state they share.

```swift
extension WindowType {
    static let inspector = WindowType("notes.inspector")
}

struct NotePage: View {
    let title: String
    var body: some View { Text(title) }
}

struct NotesScene: Scene {
    var body: some Scene {
        WindowGroup { NotePage(title: "Notes") }
        Window(.inspector) { NotePage(title: "Inspector") }
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
<thead><tr><th>Host</th><th>Created</th><th>Members (4)</th><th>Realization</th></tr></thead>
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>4 ✅</td><td><code>NSApplication</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>3 ✅</td><td><code>UIApplication</code> / <code>UIWindowScene</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>3 ✅</td><td><code>Application</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>4 ✅</td><td><code>Application</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>4 ✅</td><td><code>GtkApplication</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>3 ✅ · 1 –</td><td><code>document</code> / structure</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>activated</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>deactivated</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td><code>stopped</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>windowClosed</code></td><td>event</td><td><code>String</code></td><td>adaptive</td><td align="center">✅</td><td align="center">⏸</td><td align="center"></td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: waits on Window.windowType, not realized yet<br>Android Views: not realized<br>Web: A page's one window closes with its tab, which hears nothing after.</td></tr></tbody>
</table>
