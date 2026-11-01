<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Application

The application at the root of a StateUI tree, and what its host does for it with no control behind it: questions for the user, the files they open and save, what the system launches and what the user shares, the clock and the time zone, the screen reader, the clipboard, what is kept.

```swift
struct NotesApp: Application {
    var body: some Scene { WindowGroup { NotesPage() } }
}

struct NotesPage: View {
    @Environment(\.window) private var window

    var body: some View {
        Button("About")
            .onClicked(.ignoreWhileRunning) { try await window.alert("Notes", message: "Version 1.0") }
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
<tbody><tr></tr><tr><td>AppKit</td><td align="center">✅</td><td>11 ✅ · 11 ✓ · 1 –</td><td><code>NSApplication</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>UIKit</td><td align="center">⌛</td><td></td><td><code>UIApplication</code> / structure, a <code>UIWindowScene</code> per window</td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">⌛</td><td></td><td>structure / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">⌛</td><td></td><td><code>Application</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">⌛</td><td></td><td><code>AdwApplication</code> / structure</td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">⌛</td><td></td><td><code>document</code> / structure</td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/ApplicationContract.swift`.

## Application's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td rowspan="2"><code>alert</code></td><td>act</td><td><code>(Name, Name, String, String, String) -&gt; Void</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a question: the captions the host keeps, not the alert's buttons</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>announce</code></td><td>act</td><td><code>(String) -&gt; Void</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read what the screen reader said: the host's own list of what it announced</td></tr></tbody>
<tbody><tr></tr><tr><td><code>cancelCall</code></td><td>act</td><td><code>(Int) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>chooseAction</code></td><td>act</td><td><code>(Name, Name, String, [String], Int?, String) -&gt; Int?</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a question: the captions the host keeps, not the alert's buttons</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>confirm</code></td><td>act</td><td><code>(Name, Name, String, String, String, String) -&gt; Bool</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a question: the captions the host keeps, not the alert's buttons</td></tr></tbody>
<tbody><tr></tr><tr><td><code>currentTime</code></td><td>act</td><td><code>() -&gt; [Double]</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>handlerFailed</code></td><td>act</td><td><code>(String) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>hideOnScreenKeyboard</code></td><td>act</td><td><code>(Name, Name) -&gt; Bool</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>launchFile</code></td><td>act</td><td><code>(ChosenFile) -&gt; Bool</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a file dialog: the host's own panel, held unshown</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>launchLink</code></td><td>act</td><td><code>(String) -&gt; Bool</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a file dialog: the host's own panel, held unshown</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>openFiles</code></td><td>act</td><td><code>(Name, Name, [FileType], Bool) -&gt; [ChosenFile]</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a file dialog: the host's own panel, held unshown</td></tr></tbody>
<tbody><tr></tr><tr><td><code>persistSceneValue</code></td><td>act</td><td><code>(Name, Name, PropValue) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>persistValue</code></td><td>act</td><td><code>(Name, PropValue) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>prompt</code></td><td>act</td><td><code>(Name, Name, String, String, String, String, String?, Int?, InputPurpose, String) -&gt; String?</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a question: the captions the host keeps, not the alert's buttons</td></tr></tbody>
<tbody><tr></tr><tr><td><code>readClipboard</code></td><td>act</td><td><code>() -&gt; String?</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>readFile</code></td><td>act</td><td><code>(ChosenFile, Int?) -&gt; [UInt8]</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a file dialog: the host's own panel, held unshown</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>saveFile</code></td><td>act</td><td><code>(Name, Name, [UInt8], String, [FileType]) -&gt; ChosenFile?</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a file dialog: the host's own panel, held unshown</td></tr></tbody>
<tbody><tr></tr><tr><td><code>sendRequest</code></td><td>act</td><td><code>(String, Name, [String], [UInt8]) -&gt; (Int, [String], [UInt8])</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>share</code></td><td>act</td><td><code>(Name, Name, String?, String?) -&gt; Bool</code></td><td></td><td align="center">✓</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read a share sheet: the host's own picker, held unshown</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>useAccentColor</code></td><td>act</td><td><code>(Color?) -&gt; Void</code></td><td></td><td align="center">–</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr>
<tr><td colspan="9">AppKit: The user's accent stands on the Mac: StateUI does not override it with the application's.</td></tr></tbody>
<tbody><tr></tr><tr><td><code>useColorScheme</code></td><td>act</td><td><code>(ColorScheme) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>utcOffset</code></td><td>act</td><td><code>(String?, CalendarDate?) -&gt; Int</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
<tbody><tr></tr><tr><td><code>writeClipboard</code></td><td>act</td><td><code>(String) -&gt; Void</code></td><td></td><td align="center">✅</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td><td align="center">⌛</td></tr></tbody>
</table>
