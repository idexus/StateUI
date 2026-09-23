<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ModalStack

The pages presented over a window, the last of them on top.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

ModalStack declares no members of its own.

Realization:

- **MAUI**: modal `Page` (`PushModalAsync`)
- **AppKit**: sheet `NSWindow`
- **UIKit**: `present(_:animated:)`
- **GTK 4**: modal `GtkWindow`; libadwaita `AdwDialog`
- **Android Views**: full-screen `Dialog` (?)
- **WinUI 3**: `ContentDialog` (?)
- **Web**: `<dialog>` with `showModal()`
