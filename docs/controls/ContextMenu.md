<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ContextMenu

The menu a view offers where the user asks for one - a secondary click, a long press.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ContextMenuContract.swift`.

## ContextMenu's own members

ContextMenu declares no members of its own.

Realization:

- **AppKit**: `NSMenu` / `NSMenuItem`
- **UIKit**: `UIMenu` / `UIAction`
- **GTK 4**: `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar`
- **Android Views**: `PopupMenu` / `MenuItem`; no menu bar
- **WinUI 3**: `MenuFlyout` / `MenuBar`
- **Web**: ARIA `menu` / `menubar` (?)
