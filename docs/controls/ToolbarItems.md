<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItems

A page's toolbar items.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Menus/ToolbarItemsContract.swift`.

## ToolbarItems's own members

ToolbarItems declares no members of its own.

Realization:

- **AppKit**: `NSToolbarItem`; `NSMenuToolbarItem` overflow
- **UIKit**: `UIBarButtonItem`
- **GTK 4**: `GtkButton` in `GtkHeaderBar`
- **Android Views**: `Toolbar` `MenuItem`
- **WinUI 3**: `CommandBar` `AppBarButton`
- **Web**: `<button>` in an ARIA `toolbar`
