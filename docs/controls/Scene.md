<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Scene

One session of the application: its main window, the windows it opens beside it, and the state they share.

```swift
extension WindowType {
    static let inspector = WindowType("notes.inspector")
}

struct NoteWindow: Window {
    let title: String
    var page: any Page { Label(title) }
}

struct NotesScene: Scene {
    var windows: Windows {
        Windows {
            WindowGroup(.inspector) { NoteWindow(title: "Inspector") }
        } main: {
            NoteWindow(title: "Notes")
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
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (6) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 6 ✅ | `NSApplication` / structure |  |
| UIKit | ✅ | 4 ✅ | `UIApplication` / `UIWindowScene` |  |
| Android Views | ✅ | 4 ✅ | `Application` / structure |  |
| WinUI 3 | ✅ | 6 ✅ | `Application` / structure |  |
| GTK 4 | ✅ | 1 ✅ | `GtkApplication` / structure |  |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot switchAway on Window - GTK's driver has no path for it yet |
| `deactivated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot switchAway on Window - GTK's driver has no path for it yet |
| `destroying` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `stopped` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | · |  | GTK 4: cannot switchAway on Window - GTK's driver has no path for it yet |
| `windowClosed` | event | `String` | adaptive | ✅ | ⏸ |  | ✅ | · |  | UIKit: waits on Window.windowType, not realized yet; Android Views: not realized; GTK 4: cannot start an application - GTK's driver has no path for it yet |
| `windowRestored` | event | `(String, String?)` | adaptive | ✅ |  |  | ✅ | · |  | UIKit: not realized; Android Views: not realized; GTK 4: cannot start an application - GTK's driver has no path for it yet |
