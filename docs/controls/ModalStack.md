<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ModalStack

An arrangement presenting pages over the page it holds: its first child is that page, the others the sheets over it, the last on top.

Layer: `adaptive`. Every base host presents it by its platform's conventions, keeping StateUI's state contract.

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

| Host | Created | Members (1) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit | ✅ | 1 ✅ | sheet `NSWindow` |  |
| UIKit | ✅ | 1 ✅ | `present(_:animated:)` |  |
| Android Views | ✅ | 1 ✅ | full-screen `Dialog` (?) |  |
| WinUI 3 | ⌛ |  | `ContentDialog` (?) |  |
| GTK 4 | ⌛ |  | modal `GtkWindow`; libadwaita `AdwDialog` |  |
| Web |  |  | `<dialog>` with `showModal()` | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `popped` | event | `Int` | adaptive | ✅ | ✅ | ✅ |  |  |  |  |
