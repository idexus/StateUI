# Pictures

An application's pictures stand in its `Resources` as SVG and the bitmap
formats. AppKit, GTK, WinUI and the Web draw SVG themselves and get the
folder as it is; a head whose toolkit draws no SVG - UIKit's, Android's - gets
each SVG drawn, and every macOS bundle gets an icon drawn from
`Resources/AppIcon/appicon_macos.svg`, the artwork already on macOS's icon
grid; every iOS bundle and Android head one composed of `appicon_bkg.svg` and
`appicon_mark.svg`, which iOS rounds itself and Android's launcher masks.

## The renderer

Every picture is drawn by `resvg` of one pinned release, 0.50.0, on every
machine - so a picture is the same pixels wherever a head is built (`Resvg`).
The machine installs it: `STATEUI_RESVG` names it, else the search path finds
it; another release, or none, is refused with how to get the pinned one
(`brew install resvg`, `cargo install resvg --version 0.50.0`, its release
archive). Nothing of it is shipped or checked in, so a built application
carries only what it drew. `stateui doctor` checks it on a Mac, for the heads
a Mac builds.

## What StateUI draws

StateUI owns the policy, the renderer only the pixels (`Pictures`): one SVG at
a scale of its own size; a folder's SVGs as `<name>@3x.png` - three pixels a
point, what the densest common screens show at one pixel a pixel - with every
other picture carried as it is, only what changed since it was drawn drawn
again, and a picture whose source went taken away; and a macOS icon set, 16,
32, 128, 256 and 512 points at one and two pixels a point. A picture made of
layers, or one standing over a part of its square, is drawn through an SVG
that holds the layers, each stretched over its fraction of the square about
the middle - a square is always the square asked for.

The system's own formats stay its tools' to write, on the Apple machines that
build them: `iconutil` makes the bundle's `.icns` from the icon set - ImageIO's
ICNS writer cannot tell a point size at two pixels a point from the size twice
as large at one - and `actool` compiles an iOS icon's catalog
(apple-bundles.md).

An iOS icon is an asset catalog whose `AppIcon` is one 1024-pixel square,
opaque as iOS asks: the background drawn over the whole of it, the mark over
that - the mark takes as much of the square as it takes of what a launcher
shows elsewhere - drawn again only where either layer changed, and its alpha
channel then dropped through Core Graphics. An Android launcher icon is
adaptive: its background and its foreground - the mark at two thirds of a
108 dp canvas about its middle, its monochrome layer too - at every density.
