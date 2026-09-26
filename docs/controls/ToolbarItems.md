<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# ToolbarItems

A page's toolbar items.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

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
