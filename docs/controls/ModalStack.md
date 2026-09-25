<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ModalStack

The pages presented over a window, the last of them on top.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Navigation/ModalStackContract.swift`.

## ModalStack's own members

ModalStack declares no members of its own.

Realization:

- **AppKit**: sheet `NSWindow`
- **UIKit**: `present(_:animated:)`
- **GTK 4**: modal `GtkWindow`; libadwaita `AdwDialog`
- **Android Views**: full-screen `Dialog` (?)
- **WinUI 3**: `ContentDialog` (?)
- **Web**: `<dialog>` with `showModal()`
