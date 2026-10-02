<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Window

A window onto a page.

```swift
struct MainWindow: Window {
    var page: any Page { MainPage() }
}

struct MainPage: ContentView {
    @Environment private var window: WindowSession

    var content: some View {
        Label("Hello")
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

| Host | Created | Members (22) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 15 ✅ · 6 ✓ | `NSWindow` |  |
| UIKit | ✅ | 3 ✅ · 4 ✓ | `UIWindow` |  |
| Android Views | ✅ | 2 ✅ · 4 ✓ | `Activity` |  |
| WinUI 3 | ✅ | 22 ✅ | `Window` |  |
| GTK 4 | ✅ | 8 ✅ · 6 ✓ · 8 – | `GtkApplicationWindow` |  |
| Web |  |  | browser `window` | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/WindowContract.swift`.

## Window's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `created` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `deactivated` | event |  | adaptive | ✓ | ✓ | ✓ | ✅ | ✓ |  | only through the host's own: switchAway on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: only through the host's own: switchAway on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: switchAway on Window: the host told the activity's phase, no activity moved; GTK 4: only through the host's own: switchAway on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows |
| `destroying` | event |  | adaptive | ✅ | ✓ | ✓ | ✅ | ✅ |  | UIKit: only through the host's own: close on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: close on Window: the host told the activity's phase, no activity moved |
| `floatsOnTop` | property | `Bool` | adaptive | ✓ |  |  | ✅ | – |  | only through the host's own: bringToFront on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: not realized; Android Views: not realized; GTK 4: GTK 4 keeps no window above the others: the desktop stacks them. |
| `height` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: not realized; Android Views: not realized |
| `hidesWhenInactive` | property | `Bool` | adaptive | · |  |  | ✅ | ✓ |  | cannot read isVisible of Window - AppKit's driver has no path for it yet; UIKit: not realized; Android Views: not realized; GTK 4: only through the host's own: bringToFront on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows |
| `isMaximizable` | property | `Bool` | adaptive | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: The desktop fills the screen with any GTK 4 window it can resize: none forbids that alone. |
| `isMinimizable` | property | `Bool` | adaptive | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: GTK 4 asks the desktop to keep no window from being put away. |
| `isTranslucent` | property | `Bool` | adaptive | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: GNOME draws its windows opaque: no material shows through one. |
| `maximumHeight` | property | `Double` | native | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: GTK 4 bounds no window from above. |
| `maximumWidth` | property | `Double` | native | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: GTK 4 bounds no window from above. |
| `minimumHeight` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: not realized; Android Views: not realized |
| `minimumWidth` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: not realized; Android Views: not realized |
| `resumed` | event |  | adaptive | ✓ | ✓ | ✓ | ✅ | ✓ |  | only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: minimize on Window: the host told the activity's phase, no activity moved; GTK 4: only through the host's own: minimize on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows |
| `stopped` | event |  | adaptive | ✓ | ✓ | ✓ | ✅ | ✓ |  | only through the host's own: minimize on Window: the notification AppKit would post, posted by the driver; the window does not move; UIKit: only through the host's own: minimize on Window: the host told the scene's phase, no scene moved; Android Views: only through the host's own: minimize on Window: the host told the activity's phase, no activity moved; GTK 4: only through the host's own: minimize on Window: the notice GTK's window would give, told by the driver: a desktop moves no window a test shows |
| `title` | property | `String` | native | ✅ | ✅ | · | ✅ | ✅ |  | Android Views: cannot read title of Window - Android's driver has no path for it yet |
| `width` | property | `Double` | native | ✅ |  |  | ✅ | ✅ |  | UIKit: not realized; Android Views: not realized |
| `windowType` | property | `WindowType` | structure | ✓ |  |  | ✅ | ✓ |  | only through the host's own: read windowType of Window: the host's restoration record; UIKit: not realized; Android Views: not realized; GTK 4: only through the host's own: read windowType of Window: the scenes the host keeps for the next start |
| `windowValue` | property | `String` | structure | ✓ |  |  | ✅ | ✓ |  | only through the host's own: read windowValue of Window: the host's restoration record; UIKit: not realized; Android Views: not realized; GTK 4: only through the host's own: read windowValue of Window: the scenes the host keeps for the next start |
| `x` | property | `Double` | structure | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: GNOME places its windows itself: GTK 4 asks no place of the desktop. |
| `y` | property | `Double` | structure | ✅ |  |  | ✅ | – |  | UIKit: not realized; Android Views: not realized; GTK 4: GNOME places its windows itself: GTK 4 asks no place of the desktop. |
