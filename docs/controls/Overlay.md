<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Overlay

A view shown above a window's page, over everything else it holds.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Slots/OverlayContract.swift`.

## Overlay's own members

Overlay declares no members of its own.

Realization:

- **AppKit**: pass-through `NSView` above the page
- **UIKit**: pass-through `UIView` above the page
- **GTK 4**: `GtkOverlay`
- **Android Views**: top child of a `FrameLayout`
- **WinUI 3**: top layer of a root `Grid`
- **Web**: positioned element above the page
