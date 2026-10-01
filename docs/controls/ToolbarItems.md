<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItems

A group of actions a page or an arrangement declares for its bar: one shared background where the platform draws one, joined by the groups of the same id declared further in.

```swift
@State var edited = false

TextEditor()
    .onTextChanged { _ in edited = true }
    .toolbar(.leading) {
        ToolbarItem("New")
    }
    .toolbar {
        ToolbarItem("Save")
            .isEnabled(edited)
            .onClicked { edited = false }
    }
```

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own backend for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (2) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 2 ✅ | `NSToolbarItem`; `NSMenuToolbarItem` overflow |  |
| UIKit | ✅ | 2 ✅ | `UIBarButtonItem` |  |
| Android Views | ◐ | 1 – | `Toolbar` `MenuItem` | cannot read the bar of Page - Android's driver has no path for it yet |
| WinUI 3 | ✅ | 2 ✅ | `CommandBar` `AppBarButton` |  |
| GTK 4 | ✅ | 2 ✅ | `GtkButton` in `GtkHeaderBar` |  |
| Web |  |  | `<button>` in an ARIA `toolbar` | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Menus/ToolbarItemsContract.swift`.

## ToolbarItems's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `order` | property | `Int` | stateUI | ✅ | ✅ | · | ✅ | ✅ |  | Android Views: cannot read the bar of Page - Android's driver has no path for it yet |
| `side` | property | `ToolbarSide` | adaptive | ✅ | ✅ | – | ✅ | ✅ |  | Android Views: Android's bar has no leading edge beside its navigation button: a leading group stands first among the actions. |
