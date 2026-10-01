<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

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
| 🧩 | Left to the application, which registers its own control for it with that host. |
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
| GTK 4 | ✅ | 6 ✅ | `GtkApplication` / structure |  |
| Web |  |  | `document` / structure | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Structure/SceneContract.swift`.

## Scene's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `activated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `deactivated` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `destroying` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `stopped` | event |  | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ |  |  |
| `windowClosed` | event | `String` | adaptive | ✅ | ⏸ |  | ✅ | ✅ |  | UIKit: waits on Window.windowType, not realized yet; Android Views: not realized |
| `windowRestored` | event | `(String, String?)` | adaptive | ✅ |  |  | ✅ | ✅ |  | UIKit: not realized; Android Views: not realized |
