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
<tbody><tr></tr><tr><td>UIKit</td><td align="center">✅</td><td>4 ✅ · 4 ✓ · 9 –</td><td><code>UIWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Android Views</td><td align="center">✅</td><td>4 ✅ · 4 ✓ · 13 –</td><td><code>Activity</code></td></tr></tbody>
<tbody><tr></tr><tr><td>WinUI 3</td><td align="center">✅</td><td>23 ✅</td><td><code>Window</code></td></tr></tbody>
<tbody><tr></tr><tr><td>GTK 4</td><td align="center">✅</td><td>8 ✅ · 7 ✓ · 8 –</td><td><code>GtkApplicationWindow</code></td></tr></tbody>
<tbody><tr></tr><tr><td>Web</td><td align="center">✅</td><td>4 ✅ · 4 ✓ · 15 –</td><td>browser <code>window</code></td></tr></tbody>
</table>

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

<table>
<thead><tr><th>Member</th><th>Kind</th><th>Value</th><th>Layer</th><th>AppKit</th><th>UIKit</th><th>Android Views</th><th>WinUI 3</th><th>GTK 4</th><th>Web</th></tr></thead>
<tbody><tr></tr><tr><td><code>activated</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>background</code></td><td>property</td><td><code>Color</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td><td align="center">✅</td></tr>
<tr><td colspan="9">GTK 4: only through the host's own: read background of Window: the class of the host's style sheet the widget wears: GTK reads back no background</td></tr></tbody>
<tbody><tr></tr><tr><td><code>created</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>deactivated</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: switchAway on Window: the notification AppKit would post, posted by the driver; the window does not move<br>UIKit: only through the host's own: switchAway on Window: the host told the scene's phase, no scene moved<br>Android Views: only through the host's own: switchAway on Window: the host told the activity's phase, no activity moved<br>GTK 4: only through the host's own: switchAway on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows<br>Web: only through the host's own: switchAway on Window: the notice the browser gives as the user goes elsewhere, told by the driver: a page moves no window</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>destroying</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✅</td><td align="center">✓</td></tr>
<tr><td colspan="9">UIKit: only through the host's own: close on Window: the host told the scene's phase, no scene moved<br>Android Views: only through the host's own: close on Window: the host told the activity's phase, no activity moved<br>Web: only through the host's own: close on Window: the notice the browser gives as it leaves the page, told by the driver: a page closes no tab</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>floatsOnTop</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✓</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: bringToFront on Window: the notification AppKit would post, posted by the driver; the window does not move<br>UIKit: iPadOS stacks its windows itself: UIKit keeps none above the others.<br>Android Views: Android stacks windows itself: an activity keeps none above the others.<br>GTK 4: GTK 4 keeps no window above the others: the desktop stacks them.<br>Web: A page keeps no browser window above the others: the system stacks them.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>height</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: iPadOS sizes its windows itself - the user drags a corner: a UIKit scene asks for no size.<br>Android Views: Android sizes an activity's window itself - the user drags its edge: an activity asks for no size.<br>Web: A page sizes no browser window: the user does, and the page fills it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>hidesWhenInactive</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">·</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✓</td><td align="center">–</td></tr>
<tr><td colspan="9">AppKit: cannot read isVisible of Window - AppKit's driver has no path for it yet<br>UIKit: iPadOS shows an application's windows itself: UIKit hides none while another is in front.<br>Android Views: Android shows an activity itself: it hides none while another application is in front.<br>GTK 4: only through the host's own: bringToFront on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows<br>Web: The browser shows a page whenever its tab shows, whichever application the user is in.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isMaximizable</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: Any iPadOS window may fill the screen: UIKit keeps none from it.<br>Android Views: Any Android window may fill the screen: an activity keeps none from it.<br>GTK 4: The desktop fills the screen with any GTK 4 window it can resize: none forbids that alone.<br>Web: A page asks nothing of how the browser's window is resized.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isMinimizable</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: Any iPadOS window may be put away: UIKit keeps none from it.<br>Android Views: Any Android window may be put away: an activity keeps none from it.<br>GTK 4: GTK 4 asks the desktop to keep no window from being put away.<br>Web: A page asks nothing of how the browser's window is put away.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>isTranslucent</code></td><td>property</td><td><code>Bool</code></td><td>adaptive</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: iPadOS draws an application's window opaque: no material shows through one.<br>Android Views: An activity is translucent by the theme it starts in: a window cannot turn it so.<br>GTK 4: GNOME draws its windows opaque: no material shows through one.<br>Web: A page draws its window opaque: no material of the system shows through it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>maximumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: Android bounds an activity's window itself: an activity sets it no bound at run time.<br>GTK 4: GTK 4 bounds no window from above.<br>Web: A page bounds no browser window: the user sizes it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>maximumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: Android bounds an activity's window itself: an activity sets it no bound at run time.<br>GTK 4: GTK 4 bounds no window from above.<br>Web: A page bounds no browser window: the user sizes it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>minimumHeight</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: Android bounds an activity's window itself: an activity sets it no bound at run time.<br>Web: A page bounds no browser window: the user sizes it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>minimumWidth</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center"></td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: not realized<br>Android Views: Android bounds an activity's window itself: an activity sets it no bound at run time.<br>Web: A page bounds no browser window: the user sizes it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>resumed</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move<br>UIKit: only through the host's own: minimize on Window: the host told the scene's phase, no scene moved<br>Android Views: only through the host's own: minimize on Window: the host told the activity's phase, no activity moved<br>GTK 4: only through the host's own: minimize on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows<br>Web: only through the host's own: minimize on Window: the notice the browser gives as the page's tab hides, told by the driver: a page hides no tab</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>stopped</code></td><td>event</td><td></td><td>adaptive</td><td align="center">✓</td><td align="center">✓</td><td align="center">✓</td><td align="center">✅</td><td align="center">✓</td><td align="center">✓</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move<br>UIKit: only through the host's own: minimize on Window: the host told the scene's phase, no scene moved<br>Android Views: only through the host's own: minimize on Window: the host told the activity's phase, no activity moved<br>GTK 4: only through the host's own: minimize on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows<br>Web: only through the host's own: minimize on Window: the notice the browser gives as the page's tab hides, told by the driver: a page hides no tab</td></tr></tbody>
<tbody><tr></tr><tr><td><code>title</code></td><td>property</td><td><code>String</code></td><td>native</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td><td align="center">✅</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>width</code></td><td>property</td><td><code>Double</code></td><td>native</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">✅</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: iPadOS sizes its windows itself - the user drags a corner: a UIKit scene asks for no size.<br>Android Views: Android sizes an activity's window itself - the user drags its edge: an activity asks for no size.<br>Web: A page sizes no browser window: the user does, and the page fills it.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>windowType</code></td><td>property</td><td><code>WindowType</code></td><td>structure</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✅</td><td align="center">✓</td><td align="center">–</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read windowType of Window: the host's restoration record<br>UIKit, Android Views: not realized<br>GTK 4: only through the host's own: read windowType of Window: the scenes the host keeps for the next start<br>Web: A page is one window: it opens none of a kind.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>windowValue</code></td><td>property</td><td><code>String</code></td><td>structure</td><td align="center">✓</td><td align="center"></td><td align="center"></td><td align="center">✅</td><td align="center">✓</td><td align="center">–</td></tr>
<tr><td colspan="9">AppKit: only through the host's own: read windowValue of Window: the host's restoration record<br>UIKit, Android Views: not realized<br>GTK 4: only through the host's own: read windowValue of Window: the scenes the host keeps for the next start<br>Web: A page is one window: it opens none for a value.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>x</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: iPadOS places its windows itself: a UIKit scene asks for no place.<br>Android Views: Android places an activity's window itself: an activity asks for no place.<br>GTK 4: GNOME places its windows itself: GTK 4 asks no place of the desktop.<br>Web: A page places no browser window: the system does.</td></tr></tbody>
<tbody><tr></tr><tr><td rowspan="2"><code>y</code></td><td>property</td><td><code>Double</code></td><td>structure</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td><td align="center">✅</td><td align="center">–</td><td align="center">–</td></tr>
<tr><td colspan="9">UIKit: iPadOS places its windows itself: a UIKit scene asks for no place.<br>Android Views: Android places an activity's window itself: an activity asks for no place.<br>GTK 4: GNOME places its windows itself: GTK 4 asks no place of the desktop.<br>Web: A page places no browser window: the system does.</td></tr></tbody>
</table>
