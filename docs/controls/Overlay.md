<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Overlay

A view shown above a window's page, over everything else it holds.

Layer: `structure`. It carries structure or protocol data rather than configuring a visual platform object.

Inherits nothing: every member below is its own.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/OverlayContract.swift`.

## Overlay's own members

Overlay declares no members of its own.

Realization:

- **MAUI**: `IWindowOverlay` layer
- **AppKit**: pass-through `NSView` above the page
- **UIKit**: pass-through `UIView` above the page
- **GTK 4**: `GtkOverlay`
- **Android Views**: top child of a `FrameLayout`
- **WinUI 3**: top layer of a root `Grid`
- **Web**: positioned element above the page
